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
data.closeOnEnd = true

# capture our events so we can disply the results in a deterministic order
c = new EpiClient "ws://localhost:8080/sockjs/websocket"
c.rowOutput = []
c.dataOutput = []
c.on 'beginQuery', (msg) -> c.beginQueryOutput = 'beginQuery' + JSON.stringify msg
c.on 'endQuery', (msg) ->
   c.endQueryOutput = 'endQuery' + JSON.stringify msg
c.on 'row', (msg) ->
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'data', (msg) ->
  c.rowOutput.push 'data' + JSON.stringify msg
c.on 'close', () -> exitWhenDone()
c.query connectionName, template, data, "basicSocketQueryId"

exitWhenDone = _.after 1, () ->
  console.log c.beginQueryOutput
  console.log c.endQueryOutput

  for row in c.rowOutput
    console.log row
  for row in c.dataOutput
    console.log row
  process.exit 0
