# vim:ft=coffee

async       = require 'async'
log         = require './util/log.coffee'
_           = require 'lodash-contrib'
path        = require 'path'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'
transformer = require './transformer.coffee'

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
    (err, rawTemplate, renderedTemplate) ->
      context.rawTemplate = rawTemplate
      log.debugRequest context.debug, "raw template: \n #{context.rawTemplate}"
      context.renderedTemplate = renderedTemplate
      log.debugRequest context.debug, "rendered template: \n #{context.renderedTemplate}"
      callback err, context
  )

executeQuery = (context, callback) ->
  context.emit 'beginqueryexecution'
  queryCompleteCallback = (err, data) ->
    context.Stats.endDate = new Date()
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] error executing query #{err}"
      context.emit 'error', err, data

    context.emit 'endquery', data
    core.removeInflightQuery context.templateName
    callback null, context
  query.execute(
    context.driver,
    context,
    queryCompleteCallback
  )

collectStats = (context, callback) ->
  stats = context.Stats
  stats.executionTimeInMillis = stats.endDate.getTime() - stats.startDate.getTime()
  core.QueryStats.buffer.store stats
  # storing the exec time for this query so we can track recent query
  # times by template
  core.storeQueryExecutionTime(
    context.templateName
    stats.executionTimeInMillis
  )
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
    executeQuery,
    collectStats
  ],
  (err, results) ->
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] queryRequestHandler Error: #{err}"
      context.emit 'error', err
    context.emit 'completequeryexecution'

module.exports.queryRequestHandler = queryRequestHandler
