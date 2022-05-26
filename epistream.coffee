#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee

cluster   = require 'cluster'
http      = require 'http'
log       = require 'simplog'
sockjs    = require 'sockjs'

app       = require './app.coffee'
config    = require './src/config.coffee'
Context   = require('./src/context').Context
queryRequestHandler = require('./src/request.coffee').queryRequestHandler
#master code to clean
request = require("request-promise");
async = require('asyncawait/async');
await = require('asyncawait/await');
### http = require 'http'
request = require("request-promise");
async = require('asyncawait/async');
await = require('asyncawait/await');
app = express()
# based on https://stackoverflow.com/a/19965089/2733
app.use express.json({ limit: '26mb' })
app.use express.urlencoded({ extended: true, limit: '26mb', parameterLimit: 5000 })
app.use '/static', express.static(path.join(__dirname, 'static'))

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


app.get '/diagnosticall', (req, res) ->
  response =
    message: "ok"
    connections: _.map(config.connections, (conn) -> { driver: conn.driver, name: conn.name, server: conn.config?.server, timeout: conn.config?.options?.requestTimeout, port: conn.config?.options?.port })
  if config.isDevelopmentMode()
    response.aclsEnabled = config.enableTemplateAcls
  res.send response

app.get '/diagnostictest', async (req, res) ->
  connections = [];
  epi_connections= _.pluck(_.where(config.connections, {driver: "mssql"}),'name');
  for connection in epi_connections
    try
      results = await request 'http://localhost:'+process.env.PORT+'/epiquery1/'+connection+'/test/servername'
      result = JSON.parse(results)
      console.log "Name :" + connection
      console.log Object.values(result[0])[0] 
      console.log result
      connections.push {"connectionname": connection, "server": result[0], "server": Object.values(result[0])[0]}
    catch e
      connections.push {"connectionname": connection, "error": JSON.parse(e.error.replace(/\\/g, ''))}
  res.send connections
      

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
  c = new Context()
  # there are no tests for req.params.queryId, but the implementation is based on
  # the documentation for the deprecated request.params() method:
  # http://expressjs.com/en/api.html#req.param
  c.queryId = req.params.queryId || req.body?.queryId || req.query.queryId
  _.extend c, httpClient.getQueryRequestInfo(req)

  if c.connectionName and not config.connections[c.connectionName]
    res.send error: "unable to find connection by name '#{c.connectionName}'"
    return
  httpClient.attachResponder c, res
  c.requestedTemplatePath = req.path
  queryRequestHandler(c) ###
#End master stuffs
sockjsClient        = require './src/transport/sockjs.coffee'

socketServer = sockjs.createServer(app, options: disconnect_delay: 900000)

socketServer.on 'connection', (conn) ->
  conn.on 'data', (message) ->
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

server = http.createServer(app)

prefix = {prefix: '/sockjs'}

socketServer.installHandlers(server, prefix)

log.debug "server worker process starting with configuration"
log.debug "%j", config
log.debug "node version", process.version

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
