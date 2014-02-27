#! /usr/bin/env coffee

WebSocket     = require 'ws'
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'
clients       = require '../../src/clients/EpiClient.coffee'

EpiBufferingClient = clients.EpiBufferingClient
EpiClient = clients.EpiClient


template = process.argv[3]
connectionName = process.argv[2]
data = JSON.parse(process.argv[4] || "{}")
repeatCount = Number(process.argv[5] || 1)
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080

# capture our events so we can disply the results in a deterministic order
c = new EpiClient "ws://localhost:8080/sockjs/websocket"
c.rowOutput = []
c.dataOutput = []

exitWhenDone = _.after(repeatCount, () ->
  console.log c.beginQueryOutput
  console.log c.endQueryOutput

  for row in c.rowOutput
    console.log row
  for row in c.dataOutput
    console.log row
  process.exit 0
)
c.on 'beginQuery', (msg) ->
  c.beginQueryOutput = 'beginQuery' + JSON.stringify msg
c.on 'row', (msg) ->
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'data', (msg) ->
  c.rowOutput.push 'data' + JSON.stringify msg
c.on 'endQuery', (msg) ->
  c.endQueryOutput = 'endQuery' + JSON.stringify msg
  exitWhenDone()

if repeatCount is 1
  c.query(connectionName, template, data, "basicSocketQueryId")
else
  c.query(connectionName, template, data, "basicSocketQueryId#{num}") for num in [1..repeatCount]
