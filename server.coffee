#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee
 
express   = require 'express'
_         = require 'underscore'
path      = require 'path'
log       = require 'simplog'
sockjs    = require 'sockjs'
http      = require 'http'
Context   = require('./src/context').Context
core      = require './src/core.coffee'
config    = require './src/config.coffee'
sse       = require './src/transport/sse.coffee'
sockjsClient  = require './src/transport/sockjs.coffee'
httpClient          = require './src/transport/http.coffee'
queryRequestHandler  = require('./src/request.coffee').queryRequestHandler

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()


socketServer = sockjs.createServer(app)

# initialize the core including driver loading, etc.
core.init()

app.get '/diagnostic', (req, res) ->
  response =
    message: "ok"
    connections: _.pluck(config.connections, 'name')
  res.send response

app.get '/sse', (req, res) ->
  # providing the client_id is specifically for testing, if you're doing it
  # for any other reason you're doing it in an un-intended manner
  client_id = req.param('client_id')
  sse.createClient req, res, client_id

app.get "/close/:client_id", (req, res) ->
  log.info "terminate requested for #{req.params.client_id}"
  client = sse.getConnectedClientById(req.params.client_id)
  if client
    log.debug "terminating client #{req.params.client_id}"
    client.close()
  res.writeHead(200, {'Content-Type': 'text/html'})
  res.write "\n"
  res.end()

httpRequestHandler = (req, res) ->
  clientId = req.param 'client_id'
  c = new Context()
  _.extend c, httpClient.getQueryRequestInfo(req)
  if c.connectionName and not config.connections[c.connectionName]
    res.send error: "unable to find connection by name '#{c.connectionName}'"
    return
  if clientId
    # handling an sse request
    log.debug "looking for an sse client by id: #{clientId}"
    c.closeOnEnd = req.param('close_on_end') is 'true'
    client = sse.getConnectedClientById clientId
    if not client
      log.error "unable to find client by id #{clientId}"
      res.send error: "no client found by id #{clientId}"
      return
    sse.attachResponder c, client.res
    res.send {message: "QueryRequest Recieved"}
  else
    # normal ol' http request
    httpClient.attachResponder c, res
  c.requestedTemplatePath = req.path
  queryRequestHandler(c)

socketServer.on 'connection', (conn) ->
  log.debug "we got a client"
  conn.on 'data', (message) ->
    log.debug "inbound sockjs message #{message}"
    message = JSON.parse(message)
    ctxParms =
      templateName: message.templateName
      closeOnEnd: message.closeOnEnd
      connectionName: message.connectionName
      queryId: message.queryId
      params: message
    context = new Context(ctxParms)
    sockjsClient.attachResponder(context, conn)
    queryRequestHandler(context)
  conn.on 'close', () ->
    log.debug "sockjs client disconnected"

app.get /\/(.+)$/, httpRequestHandler
app.post /\/(.+)$/, httpRequestHandler
  
log.info "server starting with configuration"
log.info "%j", config
server = http.createServer(app)
socketServer.installHandlers(server, {prefix: '/sockjs'})
server.listen(config.port)
