#! /usr/bin/env coffee

# so, it used to be that the client supported both browser and server (node)
# side usage.  This is no longer the case, but with some tweaking we can
# make it work at all and thus leverage the old (server side) tests
# that's what we're doing with the assignments to global
#
global.window = {}

WebSocket     = require 'ws'
global.WebSocket = WebSocket
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'
clients       = require '../../src/clients/EpiClient.coffee'
optimist      = require 'optimist'
Q             = require 'q'

EpiBufferingClient = clients.EpiBufferingClient
EpiClient = clients.EpiClient

args = optimist.argv

template = args.template
connectionName = args.connection
data = JSON.parse(args.data || "{}")
repeatCount = Number(args.repeat || 1)
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080

# capture our events so we can disply the results in a deterministic order
c = new EpiClient "ws://localhost:8080/sockjs/websocket"
c.rowOutput = []
c.dataOutput = []
c.errorOutput = []

executionComplete = Q.defer()
callMeTillDone = _.after( repeatCount, executionComplete.resolve )

dumpOutput = () ->
  console.log c.beginqueryOutput
  console.log c.endqueryOutput

  for row in c.rowOutput
    console.log row
  for row in c.dataOutput
    console.log row
  for error in c.errorOutput
    console.log error
  process.exit 0

c.on 'beginquery', (msg) ->
  c.beginqueryOutput = 'beginquery' + JSON.stringify msg
c.on 'row', (msg) ->
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'data', (msg) ->
  c.rowOutput.push 'data' + JSON.stringify msg
c.on 'endquery', (msg) ->
  c.endqueryOutput = 'endquery' + JSON.stringify msg
  callMeTillDone()
c.on 'error', (msg) ->
  c.errorOutput.push 'error' + JSON.stringify msg

if repeatCount is 1
  c.query(connectionName, template, data, "basicSocketQueryId")
else
  c.query(connectionName, template, data, "basicSocketQueryId#{num}") for num in [1..repeatCount]

timedOut = ->
  console.log "timed out!"
  process.exit 1

executionComplete.promise.then dumpOutput
setTimeout timedOut, 5000
