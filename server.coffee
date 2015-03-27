#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee

cluster   = require 'cluster'
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


# fork off child processes if master and such behavior has been requested
if process.env.FORKS
  forks = parseInt process.env.FORKS
  if cluster.isMaster
    console.log "Initializing #{forks} worker processes"
    cluster.fork() for [1..forks]
    cluster.on 'exit', (worker,code,signal) ->
      console.log "Worker #{worker.process.pid} died", code, signal
    return

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()

apiKey = process.env.EPISTREAM_API_KEY
urlBasedKey = process.env.URL_BASED_API_KEY # use second env var for backwards compatibility 

socketServer = sockjs.createServer(app, options: disconnect_delay: 900000)

# initialize the core including driver loading, etc.
core.init()

app.get '/diagnostic', (req, res) ->
  response =
    message: "ok"
    connections: _.pluck(config.connections, 'name')
  res.send response

app.get '/templates', (req, res) ->
  response =
    templates: []
  res.send response

app.get '/stats', (req, res) ->
  stats =
    # execution time data is a object contiaining 
    # "templateName": <CircularBuffer of recent exedution times>
    # properties
    recentExecutionTimes: _.map core.getQueryExecutionTimes, (v, k, l) ->
      ret = {}
      ret[k] = "#{v}"
      ret
    recentQueries: core.QueryStats.buffer.getEntries()
    inflightQueries: core.getInflightQueries()
    serverTime: new Date()
  res.send stats

httpRequestHandler = (req, res) ->
  clientId = req.param 'client_id'
  c = new Context()
  _.extend c, httpClient.getQueryRequestInfo(req, !!apiKey)
  # Check that the client supplied key matches server key
  if apiKey
    if !(c.clientKey == apiKey)
      log.error "Unauthorized HTTP Access Attempted from IP: #{req.connection.remoteAddress}"
      log.error "Unauthorized Context: #{JSON.stringify(c.templateContext)}"
      res.send error: "Unauthorized Access"
      return

  if c.connectionName and not config.connections[c.connectionName]
    res.send error: "unable to find connection by name '#{c.connectionName}'"
    return
  httpClient.attachResponder c, res
  c.requestedTemplatePath = req.path
  queryRequestHandler(c)

socketServer.on 'connection', (conn) ->
  conn.on 'data', (message) ->

    if apiKey
      if !~ conn.url.indexOf apiKey
        conn.close()
        log.error "Unauthorized Socket Access Attempted from IP: #{conn.remoteAddress}"
        log.error "Unauthorized Context: #{JSON.stringify(message)}"
        return

    log.debug "inbound message #{message}"
    if message == 'ping'
      conn.write 'pong'
      return
    message = JSON.parse(message)
    ctxParms =
      templateName: message.templateName
      closeOnEnd: message.closeOnEnd
      connectionName: message.connectionName
      queryId: message.queryId
      templateContext: message.data
    context = new Context(ctxParms)
    log.info "[q:#{context.queryId}] starting processing"
    sockjsClient.attachResponder(context, conn)
    queryRequestHandler(context)
  conn.on 'error', (e) ->
    log.error "error on connection", e
  conn.on 'close', () ->
    log.debug "sockjs client disconnected"

socketServer.on 'error', (e) ->
  log.error "error on socketServer", e

app.get /\/(.+)$/, httpRequestHandler
app.post /\/(.+)$/, httpRequestHandler
  
log.info "server worker process starting with configuration"
log.info "%j", config
log.info "node version", process.version
server = http.createServer(app)

# use key based prefix if key is in url
prefix = {prefix: '/sockjs'}
prefix.prefix = "/#{apiKey}/sockjs" if apiKey && urlBasedKey
socketServer.installHandlers(server, prefix)
server.emit 'error'
server.listen(config.port)
