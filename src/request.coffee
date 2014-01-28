# vim:ft=coffee

async       = require 'async'
log         = require 'simplog'
_           = require 'underscore'
path        = require 'path'
sse         = require './client/sse.coffee'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'
http_client = require './client/http.coffee'

buildTemplateContext = (context, callback) ->
  context.templateContext = context.params
  log.info "template context: #{JSON.stringify context.templateContext}"
  callback null, context

selectConnection = (context, callback) ->
  if not context.connectionConfig
    # no config, need to find one
    if not context.connectionName
      context.emit "no connection specified"
      callback 'no connection specified'
    context.connection = config.connections[context.connectionName]
    if not context.connection
      msg = "unable to find connection '#{context.connectionName}'"
      context.emit 'error', msg
      callback msg
  else
    context.connection = connectionConfig
  callback null, context

getTemplatePath = (context, callback) ->
  log.debug "getting template path for #{config.templateName}"
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
  context.emit 'beginQueryExecution'
  queryCompleteCallback = (err, data) ->
    if err
      log.error err
      context.emit 'error', err
    context.emit 'endQuery', data
    context.emit 'completeQueryExecution'
  query.execute driver,
    context,
    (data) -> context.emit 'beginQuery', data
    (row) -> context.emit 'row', row
    (rowsetData) -> context.emit 'beginRowSet', rowsetData
    (data) -> context.emit 'data', data
    queryCompleteCallback

queryRequestHandler = (context) ->
  async.waterfall [
    # just to create our context
    (callback) -> callback(null, context),
    buildTemplateContext,
    getTemplatePath,
    selectConnection,
    renderTemplate,
    executeQuery
  ],
  (err, results) ->
    log.error "queryRequestHandler Error: #{err}"
    context.emit 'error', err

module.exports.queryRequestHandler = queryRequestHandler
