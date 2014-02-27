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
sockjsClient        = require './src/transport/sockjs.coffee'
httpClient          = require './src/transport/http.coffee'
queryRequestHandler = require('./src/request.coffee').queryRequestHandler

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

httpRequestHandler = (req, res) ->
  clientId = req.param 'client_id'
  c = new Context()
  _.extend c, httpClient.getQueryRequestInfo(req)
  if c.connectionName and not config.connections[c.connectionName]
    res.send error: "unable to find connection by name '#{c.connectionName}'"
    return
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
