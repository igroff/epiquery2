#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee
 
express   = require 'express'
_         = require 'underscore'
path      = require 'path'
log       = require 'simplog'
events    = require 'events'
sockjs    = require 'sockjs'
http      = require 'http'
core      = require './src/core.coffee'
config    = require './src/config.coffee'
sse       = require './src/client/sse.coffee'
wsClient  = require './src/client/websocket.coffee'
http_client          = require './src/client/http.coffee'
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
  if clientId
    log.debug "looking for an sse client by id: #{clientId}"
    receiver = sse.getConnectedClientById clientId
    requestor = sse.createRequestor req, res
    if not receiver log.error "unable to find client by id #{clientId}"
      requestor.dieWith "no client found by id #{clientId}"
      return
    closeOnEnd = req.param('close_on_end') is 'true'
  else
    receiver = http_client.createClient(req, res)
    requestor = http_client.createRequestor req
    closeOnEnd = true
  context =
    receiver_client_id:clientId
    requestedTemplatePath: req.path
    closeOnEnd: closeOnEnd
    requestor: requestor
    receiver: receiver
  queryRequestHandler(context)
    
socketServer.on 'connection', (conn) ->
  conn.__client = wsClient.createClient conn
  log.debug "we got a client"
  conn.on 'data', (message) ->
    log.debug "inbound sockjs message #{message}"
    message = JSON.parse(message)
    context =
      requestedTemplatePath: message.path
      closeOnEnd: message.closeOnEnd
      requestor: wsClient.createRequestor(this, message)
      receiver: this.__client
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
