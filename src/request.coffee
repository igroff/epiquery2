# vim:ft=coffee

async       = require 'async'
log         = require 'simplog'
_           = require 'underscore'
path        = require 'path'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'


setupContext = (context, callback) ->
  # making a place to store our stats about our request
  context.Stats = {}
  context.Stats.startDate = new Date()
  context.Stats.templateName = context.templateName
  callback null, context

logTemplateContext = (context, callback) ->
  log.info "template context: #{JSON.stringify context.templateContext}"
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
  context.Stats.connectionName = context.connection.name
  callback null, context

getTemplatePath = (context, callback) ->
  log.debug "getting template path for #{context.templateName}"
  context.templatePath = path.join(config.templateDirectory,
    context.templateName)
  callback(new Error "no template path!") if not context.templatePath
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

executeQuery = (context, callback) ->
  driver = core.selectDriver context.connection
  context.emit 'beginqueryexecution'
  queryCompleteCallback = (err, data) ->
    context.Stats.endDate = new Date()
    if err
      log.error "error executing query #{err}"
      context.emit 'error', err, data

    context.emit 'endquery', data
    context.emit 'completequeryexecution'
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
    selectConnection,
    renderTemplate,
    executeQuery,
    collectStats
  ],
  (err, results) ->
    log.error "queryRequestHandler Error: #{err}"
    context.emit 'error', err

module.exports.queryRequestHandler = queryRequestHandler
