EventEmitter      = require('events').EventEmitter
_                 = require 'underscore'
log               = require 'simplog'
WebSocket         = require 'ws'


socketState = 
  CONNECTING: 0
  OPEN: 1
  CLOSING: 2
  CLOSED: 3


class EpiClient extends EventEmitter
  constructor: (@url) ->
    @connect()

  connect: =>
    return if @ws?.readyState == socketState.CONNECTING
    
    @ws = new WebSocket(@url)
    @queryId = 0
    @ws.onmessage = @onMessage
    @ws.onclose = @onClose
    @ws.onopen = () =>
      log.info "Epiclient connection opened"
    @ws.onerror = (err) ->
      log.error "ws error: ", err

  query: (connectionName, template, data, queryId=null) =>
    req =
      templateName: template
      connectionName: connectionName
      data: data
    req.queryId = null || queryId
    req.closeOnEnd = data.closeOnEnd if data
    
    if @ws.readyState == socketState.OPEN
      try 
        @ws.send JSON.stringify(req)
      catch ex
        @connect()
        setTimeout @query, 1000, connectionName, template, data, queryId
    else
      @connect()
      setTimeout @query, 1000, connectionName, template, data, queryId

  onMessage: (message) =>
    # if the browser has wrapped this for use, we'll be interested in its
    # 'data' element
    message = message.data if message.type? and message.type = 'message'
    message = JSON.parse(message) if typeof message is 'string'
    handler = @['on' + message.message]
    if handler
      handler(message)
  
  onClose: () => 
    @emit 'close', { reconnecting: true }
    @connect()

  onrow: (msg) => @emit 'row', msg
  ondata: (msg) => @emit 'data', msg
  onbeginquery: (msg) => @emit 'beginquery', msg
  onendquery: (msg) => @emit 'endquery', msg
  onerror: (msg) => @emit 'error', msg
  onbeginrowset: (msg) => @emit 'beginrowset', msg

class EpiBufferingClient extends EpiClient
  constructor: (@host, @port=80) ->
    super(@host, @port)
    @results = {}

  onrow: (msg) =>
    @results[msg.queryId].currentResultSet.push(msg.columns)
  
  onbeginrowset: (msg) =>
    newResultSet = []
    @results[msg.queryId] ||= resultSets: []
    @results[msg.queryId].currentResultSet = newResultSet
    @results[msg.queryId].resultSets.push newResultSet

module.exports.EpiClient = EpiClient
module.exports.EpiBufferingClient = EpiBufferingClient
