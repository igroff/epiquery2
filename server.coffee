#! /usr/bin/env ./node_modules/.bin/coffee
express = require 'express'
_       = require 'underscore'
path    = require 'path'
log     = require 'simplog'
sse     = require './src/sse.coffee'
core    = require './src/core.coffee'
config  = require './src/config.coffee'
query   = require './src/query.coffee'
templates = require './src/templates.coffee'

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()

core.init()

processQueryRequest = (queryRequest, onComplete) ->
  queryRequest.client.sendEvent "queryBegin",
      {template: queryRequest.templatePath}
  onRendered = (err, rawTemplate, renderedTemplate) ->
    log.debug "onRendered(#{_.toArray arguments})"
    driver = core.selectDriver queryRequest.connectionConfig
    queryRequest.renderedTemplate = renderedTemplate
    query.execute driver,
      queryRequest.connectionConfig,
      renderedTemplate,
      queryRequest.client.sendRow,
      queryRequest.client.startRowset,
      () -> queryRequest.client.sendEvent "queryComplete"
  templates.renderTemplate queryRequest.templatePath,
        queryRequest.templateContext,
        onRendered


app.get '/sse', (req, res) ->
  new sse.Client req, res

app.get /\/(.+)$/, (req, res) ->
  client = sse.getConnectedClientById(req.param('client_id'))
  if client
    # we allow people to provide any path relative to the templates directory
    # so we'll remove the initial / and keep the rest of the path while conveniently
    # dropping any parent indicators (..)
    templateContext = _.extend {}, req.body, req.query, req.headers
    qr = new query.QueryRequest(client, templateContext)
    # here we select the appropriate connection based on the inbound request
    core.selectConnection req, qr
    log.debug "using connection configuration: %j", qr.connectionConfig
    processQueryRequest qr,
        templateContext,
        qr.templatePath,
        () -> client.sendEvent "queryComplete"

  res.writeHead(200, {'Content-Type': 'text/html'})
  res.write("\n")
  res.write "Message Sent"
  res.end()


log.info "server starting with configuration"
log.info "%j", config
app.listen config.port
