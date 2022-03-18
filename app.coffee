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
