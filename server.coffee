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


app = express()
app.use express.favicon()
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()

apiKey = process.env.EPISTREAM_API_KEY
urlBasedKey = process.env.URL_BASED_API_KEY # use second env var for backwards compatibility 

socketServer = sockjs.createServer(app, options: disconnect_delay: 900000)

# initialize the core including driver loading, etc.
core.init()

if process.env.NODE_ENV == 'development'
  set_cors_headers = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', '*'
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS');
    next()

  app.use set_cors_headers

  app.all '*', set_cors_headers

  app.options '*', (req, res) ->
    res.status(200).send()

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
    log.debug "[q:#{context.queryId}] starting processing"
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
  
log.debug "server worker process starting with configuration"
log.debug "%j", config
log.debug "node version", process.version
server = http.createServer(app)

# use key based prefix if key is in url
prefix = {prefix: '/sockjs'}
prefix.prefix = "/#{apiKey}/sockjs" if apiKey && urlBasedKey

socketServer.installHandlers(server, prefix)

Cluster = require 'cluster2'
cluster = new Cluster(port: config.port, noWorkers:config.forks)
cluster.listen (cb) -> cb(server)
