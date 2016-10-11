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
  "8216": regex:  new RegExp(String.fromCharCode(8216), "gi"), "replace": "'"
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

testExecutionPermissions = (context, callback) ->
  # Processing Template ACL's must be explicitly enabled.
  return callback(null, context) if not config.enableTemplateAcls
  # If ACL Checking is enabled and front matter is not found (templateConfig)
  # it is an error condition.  This would imply that we did not find
  # ACL information in the header portion of a template
  if not context.templateConfig
    return callback(new Error("ACL Checking Enabled - Template missing ACL Config #{context.templatePath}"), context)
  # If we find front matter but it is blank or does not result in a the YAML
  # being processed correctly, or we somehow get here without any ACLS, we have
  # an error condition.
  if Object.keys(context.templateConfig).length is 0
    return callback(new Error("ACL Checking Enabled - Template Contains Invalid ACL Config #{context.templatePath}"), context)

  log.debug "acl for template #{context.templatePath}: %s", JSON.stringify(context.templateConfig, null, 2)

  # The top of a template can have the following format:
  #
  #       /*
  #       jwt-app1: 5
  #       anybitmask: 2
  #       passed: 4
  #       as: 7
  #       header: 1
  #       */
  #
  # The list above would be a set of bitmask flags.  We will allow the template
  # to proceed if we find an enabled bit between the above list and a header
  # containing a bitmask mask passed to epiquery
  #
  # For instance |
  #
  #      Success:
  #      -------
  #        conn.headers.jwt-app1 = 1
  #        templateConfig.jwt-app1 = 5 (bits 4 & 1)
  #
  #        The above mask of 5 (bits 4 and 1) has a match with the 1 field.  The
  #        template would be allowed to proceed
  #
  #      Fail:
  #      -------
  #        conn.headers.jwt-app1 = 2
  #        templateConfig.jwt-app1 = 5
  #
  #        The above mask of 5 (bits 4 and 1) does _not_ match the bit field 2
  #        Template would not be allowed to proceed
  for own key of context.templateConfig
    if context.requestHeaders[key] and (context.requestHeaders[key] & context.templateConfig[key])
      log.debug "execution allowed by acl"
      return callback null, context

  log.debug "Execution denied by acl: Headers %j template acl: %j", context.requestHeaders, context.templateConfig
  return callback(new Error("Execution denied by acl"), context)

executeQuery = (context, callback) ->
  driver = core.selectDriver context.connection
  context.emit 'beginqueryexecution'
  queryCompleteCallback = (err, data) ->
    context.Stats.endDate = new Date()
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] error executing query #{err}"
      context.emit 'error', err, data

    context.emit 'endquery', data
    core.removeInflightQuery context.templateName
    callback null, context
  query.execute(driver,
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
        def = special_characters[keyCode]
        parent[key] = value.replace def.regex, def.replace

  callback null, context

escapeInput = (context, callback) ->
  _.walk.preorder context.templateContext, (value, key, parent) ->
    if parent
      parent[key] = value.replace(/'/g, "''") if _.isString(value)
  callback null, context

queryRequestHandler = (context) ->
  async.waterfall [
    # just to create our context
    (callback) -> callback(null, context),
    initializeRequest,
    setupContext,
    logTemplateContext,
    getTemplatePath,
    escapeInput,
    sanitizeInput,
    renderTemplate,
    testExecutionPermissions,
    selectConnection,
    executeQuery,
    collectStats
  ],
  (err, results) ->
    if err
      log.error "[q:#{context.queryId}, t:#{context.templateName}] queryRequestHandler Error: #{err}"
      context.emit 'error', err
    context.emit 'completequeryexecution'

module.exports.queryRequestHandler = queryRequestHandler
