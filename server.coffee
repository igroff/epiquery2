#! /usr/bin/env ./node_modules/.bin/coffee
express = require 'express'
_       = require 'underscore'
path    = require 'path'
fs      = require 'fs'
hogan   = require 'hogan.js'
log     = require 'simplog'
sse     = require './src/sse.coffee'
core    = require './src/core.coffee'
config  = require './src/config.coffee'
query   = require './src/query.coffee'
templates = require './src/templates.coffee'

app = express()
app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use app.router
app.use express.errorHandler()
app.use express.static(path.join(__dirname, 'public'))


# load the packaged drivers, we're assuming there may be user provided
# drivers
drivers = core.loadDrivers(path.join(__dirname, 'src', 'drivers'))

processClientRequest = (client) ->
  renderedTemplate = templates.renderTemplate(client.templatePath, client.context)
  driver = core.selectDriver(client.templatePath, drivers)
  connectionConfig = core.selectConnection(client)
  query.execute driver, connectionConfig, renderedTemplate, client.sendRow, client.startRowset

app.get '/response-stream', (req, res) ->
  new sse.Client req, res

app.get /\/(.+)$/, (req, res) ->
  client = sse.getConnectedClientById(req.param('client_id'))
  template_path = req.params[0]
  if client != undefined
    log.debug "raising event for client"
    client.sendEvent template_path, "data mang!"

  res.writeHead(200, {'Content-Type': 'text/html'})
  res.write("\n")
  res.end()


PORT = process.env.PORT || 8080
app.listen PORT
console.log("Express server listening on port %d in %s mode", PORT, app.settings.env)
