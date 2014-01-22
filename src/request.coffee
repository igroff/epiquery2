# vim:ft=coffee

async       = require 'async'
log         = require 'simplog'
_           = require 'underscore'
sse         = require './client/sse.coffee'
core        = require './core.coffee'
config      = require './config.coffee'
query       = require './query.coffee'
templates   = require './templates.coffee'
http_client = require './client/http.coffee'

buildTemplateContext = (context, callback) ->
  context.templateContext = context.requestor.params
  log.info "template context: #{JSON.stringify context.templateContext}"
  callback null, context

createQueryRequest = (context, callback) ->
  context.queryRequest = new query.QueryRequest(
    context.receiver, context.templateContext, context.closeOnEnd
  )
  callback null, context

selectConnection = (context, callback) ->
  selectConnectionResult = core.selectConnection(
    context.requestor, context.queryRequest
  )
  if selectConnectionResult instanceof Error
    log.debug "failed to find connection"
    callback selectConnectionResult
  else
    log.debug("using connection configuration: %j",
      context.queryRequest.connectionConfig
    )
    context.requestor.respondWith {message: "QueryRequest Recieved"}
    callback null, context

renderTemplate = (context, callback) ->
  templates.renderTemplate(
    context.queryRequest.templatePath,
    context.queryRequest.templateContext,
    (err, rawTemplate, renderedTemplate) ->
      context.rawTemplate = rawTemplate
      context.renderedTemplate = renderedTemplate
      context.queryRequest.renderedTemplate = renderedTemplate
      callback err, context
  )

executeQuery = (context, callback) ->
  context.queryRequest.beginQuery()
  driver = core.selectDriver context.queryRequest.connectionConfig
  core.events.emit 'queryRequest', context.queryRequest
  queryCompleteCallback = (err) ->
    if err
      log.error err
      core.events.emit(
        'queryRequestError',
        {err: err, queryRequest: context.queryRequest}
      )
      context.queryRequest.sendError(err)
    context.queryRequest.endQuery()
    core.events.emit 'queryRequestComplete', context.queryRequest
  query.execute driver,
    context.queryRequest.connectionConfig,
    context.renderedTemplate,
    context.queryRequest.sendRow,
    context.queryRequest.beginRowset,
    context.queryRequest.sendData,
    queryCompleteCallback

queryRequestHandler = (context) ->
  async.waterfall [
    # just to create our context
    (callback) -> callback(null, context),
    buildTemplateContext,
    createQueryRequest,
    selectConnection,
    renderTemplate,
    executeQuery
  ],
  (err, results) ->
    log.error err
    context.requestor.sendError { error: err.message }

module.exports.queryRequestHandler = queryRequestHandler
