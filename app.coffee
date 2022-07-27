#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee

express   = require 'express'
_         = require 'underscore'
path      = require 'path'
log       = require 'simplog'
Context   = require('./src/context').Context
core      = require './src/core.coffee'
config    = require './src/config.coffee'
httpClient          = require './src/transport/http.coffee'
queryRequestHandler = require('./src/request.coffee').queryRequestHandler

request = require('request-promise');
async = require('asyncawait/async');
await = require('asyncawait/await');

app = express()
# based on https://stackoverflow.com/a/19965089/2733
app.use express.json({ limit: '26mb' })
app.use express.urlencoded({ extended: true, limit: '26mb', parameterLimit: 5000 })
app.use '/static', express.static(path.join(__dirname, 'static'))

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
  queryRequestHandler(c)

app.get /\/(.+)$/, httpRequestHandler
app.post /\/(.+)$/, httpRequestHandler

module.exports = app
