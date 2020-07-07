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
# based on https://stackoverflow.com/a/19965089/2733
app.use express.json()
app.use express.urlencoded({ extended: true, parameterLimit: 5000 })
app.use '/static', express.static(path.join(__dirname, 'static'))

apiKey = config.epistreamApiKey

socketServer = sockjs.createServer(app, options: disconnect_delay: 900000)

# initialize the core including driver loading, etc.
core.init()

if config.isDevelopmentMode()
  log.warn "epiquery2 running in development mode, this will cause requests to be slower"
  set_cors_headers = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', req.get('Origin') ? '*'
    res.header 'Access-Control-Allow-Credentials', true
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
    res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    next()
  app.use set_cors_headers
  app.all '*', set_cors_headers
  app.options '*', (req, res) ->
    res.status(200).send()

app.get '/diagnostic', (req, res) ->
  response =
    message: "ok"
    connections: _.pluck(config.connections, 'name')
  if config.isDevelopmentMode()
    response.aclsEnabled = config.enableTemplateAcls
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
  c.queryId = req.param 'queryId'
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
      requestHeaders: conn.headers
    ctxParms.debug if message.debug
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
prefix.prefix = "/#{apiKey}/sockjs" if apiKey && config.urlBasedApiKey

socketServer.installHandlers(server, prefix)

if config.isDevelopmentMode()
  log.warn "********************************************************************************"
  log.warn "epiquery is running in development mode, this will result in templates not being cached and thus"
  log.warn "reloaded on every request, this will BE SLOW"
  log.warn "********************************************************************************"

if config.forks is 1
  log.warn "********************************************************************************"
  log.warn "epiquery is running in a single fork specified, this results in a single process epiquery which will BE SLOW"
  log.warn "running on port ", config.port
  log.warn "********************************************************************************"
  server.listen(config.port)
else
  if cluster.isMaster
    # start only the requsted number of forks
    for n in [1..config.forks]
      worker = cluster.fork()
      log.info "preforked worker process #{worker.process.pid}"
    # our exit handler, this event is raised when a worker dies we want to go ahead and
    # for a new one unless it's been explicitly killed
    cluster.on('exit', (worker, code, signal) =>
      if worker.suicide
        log.info "worker #{worker.process.pid} is shutting down"
      else
        log.warn "unexpected worker death of worker pid: #{worker.process.pid} forking replacement"
        newWorker = cluster.fork()
        log.info "replaced worker of pid #{worker.process.pid} with #{newWorker.process.pid}"
    )
  else
    server.listen(config.port)
