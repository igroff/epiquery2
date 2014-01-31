EventEmitter  = require('events').EventEmitter
_             = require 'underscore'

WebSocket = global.WebSocket || global.MozWebSocket

if WebSocket
  WebSocket.prototype.on = (name, handler) ->
    if name is 'open'
      @onopen = handler
    else if name is 'close'
      @onclose = handler
    else if name is 'message'
      @onmessage = handler
    else if name is 'error'
      @onmessage = handler
else
  WebSocket = require('ws')

class EpiClient extends EventEmitter
  constructor: (@host, @port=80) ->
    if not @host
      if window and window.location
        @ws = new WebSocket("ws://#{window.location.host}/sockjs/websocket")
      else
        throw new Error "missing connection information"
    else
      @ws = new WebSocket("ws://#{@host}#{":" if @port}#{@port}/sockjs/websocket")
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
      req.closeOnEnd = data.closeOnEnd if data
      @ws.send JSON.stringify(req)

  onMessage: (message) =>
    # if the browser has wrapped this for use, we'll be interested in its
    # 'data' element
    message = message.data if message.type? and message.type = 'message'
    message = JSON.parse(message) if typeof message is 'string'
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
