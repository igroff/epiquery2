EventEmitter      = require('events').EventEmitter
_                 = require 'underscore'
log               = require 'simplog'
AwesomeWebSocket  = require('ws-additions').AwesomeWebSocket



class EpiClient extends EventEmitter
  constructor: (@url) ->
    @connect()

  connect: =>
    # we have a couple possible implementations here, HuntingWebsocket
    # expects an array of urls, so we make that if needed
    @ws = new AwesomeWebSocket(@url)
    @queryId = 0
    @ws.onmessage = @onMessage
    @ws.onclose = @onClose
    @ws.onopen = () =>
      log.debug "Epiclient connection opened"
    @ws.onerror = (err) ->
      log.error "EpiClient socket error: ", err
    @ws.onsend = @onsend

  query: (connectionName, template, data, queryId=null) =>
    req =
      templateName: template
      connectionName: connectionName
      data: data
    req.queryId = null || queryId
    req.closeOnEnd = data.closeOnEnd if data
    # if someone has asked us to close on end, we want our fancy
    # underlying reconnectint sockets to not reconnect
    @ws.forceClose = req.closeOnEnd
    
    log.debug "executing query: #{template} data:#{JSON.stringify(data)}"
    @ws.send JSON.stringify(req)

  onMessage: (message) =>
    # if the browser has wrapped this for use, we'll be interested in its
    # 'data' element
    message = message.data if message.type? and message.type = 'message'
    message = JSON.parse(message) if typeof message is 'string'
    handler = @['on' + message.message]
    if handler
      handler(message)
  
  onClose: () =>
    @emit 'close'

  onrow: (msg) => @emit 'row', msg
  ondata: (msg) => @emit 'data', msg
  onbeginquery: (msg) => @emit 'beginquery', msg
  onendquery: (msg) => @emit 'endquery', msg
  onerror: (msg) => @emit 'error', msg
  onbeginrowset: (msg) => @emit 'beginrowset', msg
  onendrowset: (msg) => @emit 'endrowset', msg
  onsend: (msg) => @emit 'send', msg

class EpiBufferingClient extends EpiClient
  constructor: (@url) ->
    super(@url)
    @results = {}

  onrow: (msg) =>
    @results[msg.queryId]?.currentResultSet?.push(msg.columns)
  
  onbeginrowset: (msg) =>
    newResultSet = []
    @results[msg.queryId] ||= resultSets: []
    @results[msg.queryId].currentResultSet = newResultSet
    @results[msg.queryId].resultSets.push newResultSet

module.exports.EpiClient = EpiClient
module.exports.EpiBufferingClient = EpiBufferingClient
