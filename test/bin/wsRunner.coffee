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


bc = new EpiBufferingClient SERVER, PORT
bc.output = []
bc.on 'beginQuery', console.log
bc.on 'endQuery', console.log
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
c = new EpiClient SERVER, PORT
c.on 'beginQuery', (msg) -> c.beginQueryOutput = 'beginQuery' + JSON.stringify msg
c.on 'endQuery', (msg) -> c.endQueryOutput = 'endQuery' + JSON.stringify msg
c.on 'row', (msg) ->
  c.rowOutput = [] || c.rowOutput
  c.rowOutput.push 'row' + JSON.stringify msg
c.on 'close', () -> exitWhenDone()
c.query connectionName, template, nextData, "nonBufferingClientQueryId"

exitWhenDone = _.after 2, () ->
  for entry in bc.output
    console.log entry
  console.log c.beginQueryOutput
  console.log c.endQueryOutput

  for row in c.rowOutput
    console.log row
  process.exit 0
