#! /usr/bin/env ./node_modules/.bin/coffee
# vim:ft=coffee
 
express   = require 'express'
_         = require 'underscore'
path      = require 'path'
log       = require 'simplog'
events    = require 'events'
core      = require './src/core.coffee'
config    = require './src/config.coffee'
sse       = require './src/sse.coffee'
queryRequestHandler  = require('./src/request.coffee').queryRequestHandler

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use '/static', express.static(path.join(__dirname, 'static'))
app.use app.router
app.use express.errorHandler()

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

app.get /\/(.+)$/, queryRequestHandler
app.post /\/(.+)$/, queryRequestHandler
  
log.info "server starting with configuration"
log.info "%j", config
app.listen config.port
