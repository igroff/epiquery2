# vim:ft=coffee

async       = require 'async'
log         = require 'simplog'
_           = require 'lodash-contrib'
path        = require 'path'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'

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

logTemplateContext = (context, callback) ->
  log.debug "[q:#{context.queryId}] template context: #{JSON.stringify context.templateContext}"
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
  log.debug "[q:#{context.queryId}] context.connection.name", context.connection.name
  if context.connection.replica_of or context.connection.replica_master
    log.debug "[q:#{context.queryId}] query is using replica setup"
    if context.rawTemplate.match(/(^|\W)(update|insert|exec|delete)\W/i)
      log.debug "[q:#{context.queryId}] Unable to implicitly determine query is replica safe", context.rawTemplate
      if context.rawTemplate.indexOf('replicasafe') != -1
        log.debug "query to replica flagged as replicasafe"
      else
        if context.connection.replica_master
          context.emit 'replicamasterwrite', context.queryId
        else
          log.debug "[q:#{context.queryId}] query to replica is a write. switching host"
          log.debug 'hostswitch template:', context.templatePath
          return callback 'replicawrite', context

  context.Stats.connectionName = context.connection.name
  callback null, context

getTemplatePath = (context, callback) ->
  log.debug "[q:#{context.queryId}] getting template path for #{context.templateName}"
  context.templatePath = path.join(config.templateDirectory,
    context.templateName)
  callback(new Error "[q:#{context.queryId}] no template path!") if not context.templatePath
  callback null, context

renderTemplate = (context, callback) ->
  templates.renderTemplate(
    context.templatePath,
    context.templateContext,
    (err, rawTemplate, renderedTemplate) ->
      context.rawTemplate = rawTemplate
      context.renderedTemplate = renderedTemplate
      callback err, context
  )

testExecutionPermissions = (context, callback) ->
  if config.enforceAcls
    log.debug "acls are in use, checking for execution permissions"
    # everyone is automatically in the all (*) group
    context.aclIdentity.push('*')
    # first we fetch our acl info from the template
    acl = context.renderedTemplate.match(///^--acl:.*$///mg)
    # if we have no acl, yet acls are enabled... it's an error we're not gonna execute 
    # anything
    if not acl
      return callback(new Error("no acl specified for template #{context.templatePath}"), context)
    # we'll get all our acl information in one place and remove the markers
    # ending up with a comma delimited string of allowances
    acl = acl.join(',').replace(/--acl:/g, '')
    # then we clean up the individual strings (remove whitespace) and create
    # an array (set) of the allowances
    acl = _.map(acl.split(','), (s) -> return s.trim())
    log.debug "acl for template #{context.templatePath}: %j", acl
    log.debug "request identity %j", context.aclIdentity
    # then we intersect the user identity with the allowances, if we get anything
    # then they're allowed to execute
    aclIntersection = _.intersection acl, context.aclIdentity
    if aclIntersection.length is 0
      log.debug "execution denied by acl"
      return callback(new Error("Execution denied by acl"), context)
    else
      log.debug "execution allowed by acl"
      return callback null, context
  else
    return callback null, context

executeQuery = (context, callback) ->
  driver = core.selectDriver context.connection
  context.emit 'beginqueryexecution'
  queryCompleteCallback = (err, data) ->
    context.Stats.endDate = new Date()
    if err
      log.error "[q:#{context.queryId}] error executing query #{err}"
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
    (callback) ->
      core.trackInflightQuery context.templateName
      callback(null, context)
    ,
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
      log.error "[q:#{context.queryId}] queryRequestHandler Error: #{err}"
      context.emit 'error', err
    context.emit 'completequeryexecution'

module.exports.queryRequestHandler = queryRequestHandler
