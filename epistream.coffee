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
