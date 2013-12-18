#! /usr/bin/env ./node_modules/.bin/coffee
express   = require 'express'
_         = require 'underscore'
path      = require 'path'
log       = require 'simplog'
sse       = require './src/sse.coffee'
core      = require './src/core.coffee'
config    = require './src/config.coffee'
query     = require './src/query.coffee'
templates = require './src/templates.coffee'

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()

# initialize the core including driver loading, etc.
core.init()

processQueryRequest = (queryRequest, onComplete) ->
  queryRequest.beginQuery()
  queryCompleteCallback = (err) ->
    if err
      log.error err
      queryRequest.sendError(err)
    queryRequest.endQuery()
  onRendered = (err, rawTemplate, renderedTemplate) ->
    log.debug "onRendered(#{_.toArray arguments})"
    driver = core.selectDriver queryRequest.connectionConfig
    queryRequest.renderedTemplate = renderedTemplate
    query.execute driver,
      queryRequest.connectionConfig,
      renderedTemplate,
      queryRequest.sendRow,
      queryRequest.beginRowset,
      queryRequest.sendData,
      queryCompleteCallback
  templates.renderTemplate queryRequest.templatePath,
        queryRequest.templateContext,
        onRendered

app.get '/sse', (req, res) ->
  # providing the client_id is specifically for testing, if you're doing it
  # for any other reason you're doing it in an un-intended manner
  client_id = req.param('client_id')
  new sse.Client req, res, client_id

app.get "/close/:client_id", (req, res) ->
  log.info "terminate requested for #{req.params.client_id}"
  client = sse.getConnectedClientById(req.params.client_id)
  if client
    log.debug "terminating client #{req.params.client_id}"
    client.close()
  res.writeHead(200, {'Content-Type': 'text/html'})
  res.write "\n"
  res.end()

# this is where we handle inbound query requests, which are defined by the
# components of the request path, so we'll be picking out the path components
queryRequestHandler = (req, res) ->
  errHandler = (err) ->
    log.error err
    res.send { error: err.message }
  client = sse.getConnectedClientById(req.param('client_id'))
  # this allows the requestor to specify that the SSE connection should be
  # closed on completion of the query, this is only intended to facilitate
  # testing
  closeOnEnd = req.param('close_on_end') is "true"
  log.debug "closeOnEnd: %s", closeOnEnd
  if client
    templateContext = _.extend {}, req.body, req.query, req.headers
    log.info "context: #{JSON.stringify templateContext}"
    qr = new query.QueryRequest(client, templateContext, closeOnEnd)
    # here we select the appropriate connection based on the inbound request
    # the information about the template path as well as the connection info
    # is stored on the QueryRequest object, which is why it's passed in
    selectConnectionResult = core.selectConnection(req, qr)
    if selectConnectionResult instanceof Error
      errHandler selectConnectionResult
    else
      log.debug "using connection configuration: %j", qr.connectionConfig
      processQueryRequest qr, qr.endQuery
      res.send {message: "QueryRequest Recieved"}
  else
      res.send {message: "Unknown client"}

app.get /\/(.+)$/, queryRequestHandler
app.post /\/(.+)$/, queryRequestHandler
  
log.info "server starting with configuration"
log.info "%j", config
app.listen config.port
