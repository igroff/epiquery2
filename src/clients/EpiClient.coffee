EventEmitter      = require('events').EventEmitter
_                 = require 'underscore'
log               = require 'simplog'
WebSocket         = require 'ws'

class EpiClient extends EventEmitter
  constructor: (@url) ->
    @ws = new WebSocket(@url)
    @queryId = 0
    @open = false
    @ws.onmessage = @onMessage
    @ws.onclose = @onClose
    @ws.onopen = () =>
      @open = true
    @ws.onerror = (err) ->
      log.error "error: ", err

  query: (connectionName, template, data, queryId=null) =>
    req =
      templateName: template
      connectionName: connectionName
      data: data
    req.queryId = null || queryId
    req.closeOnEnd = data.closeOnEnd if data
    if @open
      @ws.send JSON.stringify(req)
    else
      setTimeout @query, 1000, connectionName, template, data, queryId

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
  ondata: (msg) => @emit 'data', msg
  onbeginquery: (msg) => @emit 'beginquery', msg
  onendquery: (msg) => @emit 'endquery', msg
  onbeginResultSet: (msg) => @emit 'beginResultSet', msg

class EpiBufferingClient extends EpiClient
  constructor: (@host, @port=80) ->
    super(@host, @port)
    @results = {}

  onrow: (msg) =>
    @results[msg.queryId].currentResultSet.push(msg.columns)

  onbeginquery: (msg) =>
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
