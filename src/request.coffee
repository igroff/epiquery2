# vim:ft=coffee

async     = require 'async'
log       = require 'simplog'
_         = require 'underscore'
sse       = require './sse.coffee'
core      = require './core.coffee'
config    = require './config.coffee'
query     = require './query.coffee'
templates = require './templates.coffee'

selectClient = (context, callback) ->
  client_id = context.req.param 'client_id'
  context.client = sse.getConnectedClientById(client_id)
  if context.client
    callback null, context
  else
    callback "no client found by id: #{client_id}"

buildTemplateContext = (context, callback) ->
  context.templateContext = _.extend(
    {},
    context.req.body,
    context.req.query,
    context.req.headers
  )
  log.info "template context: #{JSON.stringify context.templateContext}"
  callback null, context

createQueryRequest = (context, callback) ->
  closeOnEnd = context.req.param('close_on_end') is "true"
  context.queryRequest = new query.QueryRequest(
    context.client, context.templateContext, closeOnEnd
  )
  callback null, context

selectConnection = (context, callback) ->
  selectConnectionResult = core.selectConnection(
    context.req, context.queryRequest
  )
  if selectConnectionResult instanceof Error
    log.debug "failed to find connection"
    callback selectConnectionResult
  else
    log.debug("using connection configuration: %j",
      context.queryRequest.connectionConfig
    )
    context.res.send {message: "QueryRequest Recieved"}
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

queryRequestHandler = (req, res) ->
  async.waterfall [
    # just to create our context
    (callback) -> callback(null, {req: req, res:res}),
    selectClient,
    buildTemplateContext,
    createQueryRequest,
    selectConnection,
    renderTemplate,
    executeQuery
  ],
  (err, results) ->
    log.error err
    res.send { error: err.message }

module.exports.queryRequestHandler = queryRequestHandler
