#! /usr/bin/env coffee

WebSocket     = require 'ws'
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'


class EpiClient extends EventEmitter
  constructor: (@host, @port=80) ->
    @ws = new WebSocket("ws://#{@host}:#{@port}/sockjs/websocket")
    @queryId = 0
    @ws.on 'message', @onMessage
    @ws.on 'close', @onClose

  query: (connectionName, template, data, queryId=null) =>
    @ws.on 'open', () =>
      req =
        templateName: template
        connectionName: connectionName
        data: data
      req.queryId = null || queryId
      req.closeOnEnd = data.closeOnEnd if data.closeOnEnd
      @ws.send JSON.stringify(req)

  onMessage: (message) =>
    message = JSON.parse(message)
    handler = @['on' + message.message]
    if handler
      handler(message)

  onClose: () => @emit 'close'
  onrow: (msg) => @emit 'row', msg
  onbeginQuery: (msg) => @emit 'beginQuery', msg
  onendQuery: (msg) => @emit 'endQuery', msg
  onbeginResultSet: (msg) => @emit 'beginResultSet', msg

class EpiBufferingClient extends EpiClient
  constructor: (@host, @port=80) ->
    super(@host, @port)
    @results = {}

  onrow: (msg) =>
    @results[msg.queryId].currentResultSet.push(msg.columns)

  onbeginQuery: (msg) =>
    newResultSet = []
    @results[msg.queryId] = resultSets: []
    @results[msg.queryId].currentResultSet = newResultSet
    @results[msg.queryId].resultSets.push newResultSet

  onbeginResultSet: (msg) =>
    newResultSet = []
    @results[msg.queryId] = resultSets: []
    @results[msg.queryId].currentResultSet = newResultSet
    @results[msg.queryId].resultSets.push newResultSet

template = process.argv[3]
connectionName = process.argv[2]
data = process.argv[4] || {}
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080

exitAfterInvoked = (expect, exitCode) ->
  totalTimes = expect
  called = 0
  () ->
    if called++ >= totalTimes
      process.exit exitCode
    
exitWhenDone = exitAfterInvoked 2, 0

bc = new EpiBufferingClient SERVER, PORT
bc.on 'beginQuery', console.log
bc.on 'endQuery', console.log
bc.on 'row', console.log
bc.query connectionName, template, data, "pants"
nextData = closeOnEnd: true
_.extend nextData, data
bc.query connectionName, template, nextData, "morePants"
bc.on 'close', () ->
  console.log 'resultSet', JSON.stringify bc.results["pants"].resultSets
  console.log 'resultSet', JSON.stringify bc.results["morePants"].resultSets
  exitWhenDone()
res = {}
# capture our events so we can disply the results in a deterministic order
c = new EpiClient SERVER, PORT
c.on 'beginQuery', (msg) -> console.log 'beginQuery', msg
c.on 'endQuery', (msg) -> console.log 'endQuery', msg
c.on 'row', (msg) -> console.log 'row', msg
c.on 'close', () -> exitWhenDone()
c.query connectionName, template, nextData, "nonBufferingClientQueryId"
