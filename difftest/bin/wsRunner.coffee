#! /usr/bin/env coffee

WebSocket     = require 'ws'
global.WebSocket = WebSocket
global.window = {}
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'
clients       = require '../../src/clients/EpiClient.coffee'
Q             = require 'q'

EpiBufferingClient = clients.EpiBufferingClient
EpiClient = clients.EpiClient


template = process.argv[3]
connectionName = process.argv[2]
data = process.argv[4] || {}
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080



bc = new EpiBufferingClient "ws://localhost:8080/sockjs/websocket"
bc.output = []
bc.beginquery = {}
bc.on 'beginquery', (msg) -> 
  bc.beginquery[msg.queryId] = msg  
bc.on 'error', (msg) -> console.log(msg)
bc.on 'row', console.log
pantsDone = Q.defer()
morePantsDone = Q.defer()
bc.on 'endquery', (msg) ->
  if msg.queryId is "pants"    
    pantsDone.resolve("pants")
  if msg.queryId is "morePants"    
    morePantsDone.resolve("morePants")
bc.query connectionName, template, data, "pants"
bc.query connectionName, template, data, "morePants"
res = {}


# capture our events so we can disply the results in a deterministic order
c = new EpiClient "ws://localhost:8080/sockjs/websocket"
nonBufferingClientDone = Q.defer()
c.rowOutput = []
c.on 'beginquery', (msg) ->
  c.beginqueryOutput = 'beginquery' + JSON.stringify msg
c.on 'endquery', (msg) ->
  c.endqueryOutput = 'endquery' + JSON.stringify msg
  nonBufferingClientDone.resolve()
c.on 'row', (msg) ->
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'error', (msg) -> console.log(msg)

c.query connectionName, template, data, "nonBufferingClientQueryId"

dumpOutput = () ->
  console.log(bc.beginquery["pants"])
  console.log(bc.beginquery["morePants"])
  console.log('resultSet'+ JSON.stringify(bc.results["morePants"].resultSets))
  console.log('resultSet'+ JSON.stringify(bc.results["pants"].resultSets))
  console.log c.beginqueryOutput
  console.log c.endqueryOutput
  for row in c.rowOutput
    console.log row
  process.exit 0

Q.all([pantsDone.promise, morePantsDone.promise, nonBufferingClientDone.promise]).done(dumpOutput)

timeOutHandler = ->
  console.log "timed out!"
  process.exit 1

setTimeout(timeOutHandler, 5000)

