# vim:ft=coffee
newrelic    = require 'newrelic'
async       = require 'async'
log         = require './util/log.coffee'
_           = require 'lodash-contrib'
path        = require 'path'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'
transformer = require './transformer.coffee'
https       = require 'https'
url         = require 'url'

breaker     = require 'circuit-breaker'
breaker_config = {
    window: 300,  # length of window in seconds
    threshold: 10, # errors and timouts tolerated within window
    request_timeout: 30, # seconds before request is considered failed
    cb_timeout: 300, # Amount of time that CB remains closed before changing to half open
}
# we track the requests as they come in so we can create unique identifiers for things
queryRequestCounter = 0

# regex to replace MS special charactes, these are characters that are known to
# cause issues in storage and retrieval so we're going to switch 'em wherever
# we find 'em
special_characters = {
  "8220": regex: new RegExp(String.fromCharCode(8220), "gi"), "replace": '"'
  "8221": regex: new RegExp(String.fromCharCode(8221), "gi"), "replace": '"'
  "8216": regex: new RegExp(String.fromCharCode(8216), "gi"), "replace": "'"
  "8217": regex: new RegExp(String.fromCharCode(8217), "gi"), "replace": "'"
  "8211": regex: new RegExp(String.fromCharCode(8211), "gi"), "replace": "-"
  "8212": regex: new RegExp(String.fromCharCode(8212), "gi"), "replace": "--"
  "189": regex: new RegExp(String.fromCharCode(189), "gi"), "replace": "1/2"
  "188": regex: new RegExp(String.fromCharCode(188), "gi"), "replace": "1/4"
  "190": regex: new RegExp(String.fromCharCode(190), "gi"), "replace": "3/4"
  "169": regex: new RegExp(String.fromCharCode(169), "gi"), "replace": "(C)"
  "174": regex: new RegExp(String.fromCharCode(174), "gi"), "replace": "(R)"
  "8230": regex: new RegExp(String.fromCharCode(8230), "gi"), "replace": "..."
}

setupContext = (context, callback) ->
  # making a place to store our stats about our request
  context.Stats = {}
  context.Stats.startDate = new Date()
  context.Stats.templateName = context.templateName
  # this query identifier is used by the client to corellate events from
  # simultaneously executing query requests
  context.queryId = context.queryId || "#{process.pid}_#{queryRequestCounter++}"
  callback null, context

initializeRequest = (context, callback) ->
  core.trackInflightQuery context.templateName
  if config.isDevelopmentMode()
    templates.init()
    transformer.init()
  log.warn "debug logging enabled for this request" if context.debug
  callback null, context

logTemplateContext = (context, callback) ->
  log.debugRequest context.debug, "[q:#{context.queryId}] template context: #{JSON.stringify context.templateContext}"
  callback null, context

selectConnection = (context, callback) ->
  if not context.connectionConfig
    # no config, need to find one
    if not context.connectionName
      context.emit "no connection specified"
      return callback 'no connection specified'
    context.connection = config.connections[context.connectionName]
    if not context.connection
      msg = "unable to find connection '#{context.connectionName}'"
      context.emit 'error', msg
      newrelic.noticeError(new Error(msg), context)
      return callback msg
  else
    context.connection = connectionConfig
  context.driver = core.selectDriver context.connection

  # Replica check here...
  log.debugRequest context.debug, "[q:#{context.queryId}] context.connection.name", context.connection.name
  if context.connection.replica_of or context.connection.replica_master
    log.debugRequest context.debug, "[q:#{context.queryId}] query is using replica setup"
    if context.rawTemplate.match(/(^|\W)(update|insert|exec|delete)\W/i)
      log.debugRequest context.debug, "[q:#{context.queryId}] Unable to implicitly determine query is replica safe", context.rawTemplate
      if context.rawTemplate.indexOf('replicasafe') != -1
        log.debugRequest context.debug, "query to replica flagged as replicasafe"
      else
        if context.connection.replica_master
          context.emit 'replicamasterwrite', context.queryId
        else
          log.debugRequest context.debug, "[q:#{context.queryId}] query to replica is a write. switching host"
          log.debugRequest context.debug 'hostswitch template:', context.templatePath
          return callback 'replicawrite', context

  context.Stats.connectionName = context.connection.name
  callback null, context

getTemplatePath = (context, callback) ->
  log.debugRequest context.debug, "[q:#{context.queryId}] getting template path for #{context.templateName}"
  # first we make sure that, if we are whitelisting templates, that
  # our requested template is in a whitelisted directory
  if config.allowedTemplates isnt null
    templateDir = path.dirname context.templateName
    log.debugRequest context.debug, "validating template dir %s against allowed templates", templateDir
    if not config.allowedTemplates[templateDir]
      return callback new Error("Template access denied: " + context.templateName), context
  # if we've arrived here then we've either got no whitelist, or we're running
  # a whitelisted template
  context.templatePath = path.join(config.templateDirectory, context.templateName)
  if not context.templatePath
    callback(new Error "[q:#{context.queryId}] no template path!")
  else
    callback null, context

renderTemplate = (context, callback) ->
  templates.renderTemplate(
    context.templatePath,
    context.templateContext,
    (err, rawTemplate, renderedTemplate, templateConfig) ->
      context.rawTemplate = rawTemplate
      context.templateConfig = templateConfig
      log.debugRequest context.debug, "raw template: \n #{context.rawTemplate}"
      context.renderedTemplate = renderedTemplate
      log.debugRequest context.debug, "rendered template: \n #{context.renderedTemplate}"
      callback err, context
  )

postToScreamer = (context) -> () ->
  if not config.epiScreamerUrl
    log.error 'You must set EPI_SCREAMER_URL in your config.'
    return
  contextString = JSON.stringify context
  screamerUrl = url.parse config.epiScreamerUrl
  options =
    hostname: screamerUrl.hostname
    path: screamerUrl.pathname
    method: 'POST'
    headers:
      'Content-Type': 'application/json'
      'Content-Length': Buffer.byteLength(contextString)

  request = https.request options
  request.on 'error', (e) -> log.error 'error when posting to epi-screamer', e
  request.write(contextString)
  request.end()


logToScreamer = (context, callback) ->
  # Only log if we're in development mode.
  # Make request but don't block epiquery on this request.
  process.nextTick postToScreamer(context) if config.isDevelopmentMode()
  # Pass along the context regardless.
  callback(null, context)

testExecutionPermissions = (context, callback) ->
  # we make it possible to disable ACL checking but make it kind of hard, you must be running in
  # development mode AND explicitly set ENABLE_TEMPLATE_ACLS to 'DISABLED', this is only a concession
  # to folks using this locally for development and backwards compatability with otherwise secured
  # instances
  return callback(null, context) if config.enableTemplateAcls is 'DISABLED'

  log.debug "templateConfig %s: %j", context.templatePath, context.templateConfig

  # we check for ANY match between the executionMasks within the template, and matching headers
  for own key of context.templateConfig?.executionMasks
    if context.requestHeaders[key] and (context.requestHeaders[key] & context.templateConfig.executionMasks[key])
      log.debug "execution allowed by acl"
      return callback null, context

  log.debug "Execution denied by acl: Headers %j template config: %j", context.requestHeaders, context.templateConfig
  return callback(new Error("Execution denied by acl"), context)

executeQuery = (context, callback) ->
  context.emit 'beginqueryexecution'
  queryCompleteCallback = (err, data) ->
    context.Stats.endDate = new Date()
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] error executing query #{err}"
      newrelic.noticeError(err, context)
      context.emit 'error', err, data

    context.emit 'endquery', data
    core.removeInflightQuery context.templateName
    callback null, context
  QueryCircuitBreaker = breaker.factory(context.templateName, query, query.execute, breaker_config )
<<<<<<< HEAD
  status = QueryCircuitBreaker.execute(context.driver, context, queryCompleteCallback)
=======
  status = QueryCircuitBreaker.execute(context.driver,context,queryCompleteCallback)  
>>>>>>> 1e2e90e9a4567ba7e951beb54051ec416b680d87
  attribs = {
    name: context.templateName,
    status: status
    connection: context.connection.name
  }
  newrelic.recordCustomEvent('Circuit_Breaker',attribs)

collectStats = (context, callback) ->
  stats = context.Stats
  stats.executionTimeInMillis = stats.endDate.getTime() - stats.startDate.getTime()
  core.QueryStats.buffer.store stats
  # storing the exec time for this query so we can track recent query
  # times by template
  core.storeQueryExecutionTime(context.templateName, stats.executionTimeInMillis)
  # supporting pooling is optional, so some drivers won't have pool details
  if context.connectionPoolKey
    log.info "[EXECUTION STATS] template: '#{context.templateName}', duration: #{stats.executionTimeInMillis}ms, connWait: #{context.connectionAcquisitionDuration}ms, pool: #{context.connectionPoolKey}"
  else
    log.info "[EXECUTION STATS] template: '#{context.templateName}', duration: #{stats.executionTimeInMillis}ms"
  callback null, context

sanitizeInput = (context, callback) ->
  _.walk.preorder context.templateContext, (value, key, parent) ->
    if _.isString value
      _.each Object.keys(special_characters), (keyCode) ->
        # do not escape our JSON data since it's JSON and does it's own thing
        # oh, and don't try to lower case things that don't have the toLowerCase
        # method, such as numbers which are the 'keys' of arrays
        return if key.toLowerCase and key.toLowerCase().startsWith 'json'
        def = special_characters[keyCode]
        value = value.replace def.regex, def.replace
      parent[key] = value
  context.unEscapedTemplateContext = _.cloneDeep context.templateContext
  if context.driver.class.prototype.escapeTemplateContext
    context.driver.class.prototype.escapeTemplateContext(context.templateContext)
  callback null, context

queryRequestHandler = (context) ->
  async.waterfall [
    # just to create our context
    (callback) -> callback(null, context),
    initializeRequest,
    setupContext,
    logTemplateContext,
    getTemplatePath,
    selectConnection,
    sanitizeInput,
    renderTemplate,
    testExecutionPermissions,
    logToScreamer,
    executeQuery,
    collectStats
  ],
  (err, results) ->
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] queryRequestHandler Error: #{err}"
      newrelic.noticeError(err, context)
      context.emit 'error', err
    context.emit 'completequeryexecution'

module.exports.queryRequestHandler = queryRequestHandler
