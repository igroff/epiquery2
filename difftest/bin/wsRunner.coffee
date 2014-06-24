#! /usr/bin/env coffee

WebSocket     = require 'ws'
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'
clients       = require '../../src/clients/EpiClient.coffee'

EpiBufferingClient = clients.EpiBufferingClient
EpiClient = clients.EpiClient


template = process.argv[3]
connectionName = process.argv[2]
data = process.argv[4] || {}
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080



bc = new EpiBufferingClient "ws://localhost:8080/sockjs/websocket"
bc.output = []
bc.on 'beginquery', (msg) -> console.log(msg)
bc.on 'endquery', (msg) -> console.log(msg)
bc.on 'row', console.log
bc.query connectionName, template, data, "pants"
nextData = closeOnEnd: true
_.extend nextData, data
bc.query connectionName, template, nextData, "morePants"
bc.on 'close', () ->
  this.output.push('resultSet'+ JSON.stringify(bc.results["pants"].resultSets))
  this.output.push('resultSet'+ JSON.stringify(bc.results["morePants"].resultSets))
  exitWhenDone()
res = {}
# capture our events so we can disply the results in a deterministic order
c = new EpiClient "ws://localhost:8080/sockjs/websocket"
c.rowOutput = []
c.on 'beginquery', (msg) ->
  c.beginqueryOutput = 'beginquery' + JSON.stringify msg
c.on 'endquery', (msg) ->
  c.endqueryOutput = 'endquery' + JSON.stringify msg
c.on 'row', (msg) ->
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'close', () ->
  exitWhenDone()

c.query connectionName, template, nextData, "nonBufferingClientQueryId"

exitWhenDone = _.after(2, () ->
  for entry in bc.output
    console.log entry
  console.log c.beginqueryOutput
  console.log c.endqueryOutput
  for row in c.rowOutput
    console.log row
  process.exit 0
)
