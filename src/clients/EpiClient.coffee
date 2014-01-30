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

module.exports.EpiClient = EpiClient
module.exports.EpiBufferingClient = EpiBufferingClient
