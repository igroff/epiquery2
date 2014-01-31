### What's this?

So, it's very convenient to handle the nuts-and-bolts of connecting to Epi
for the user, doing things like buffering responses, raising matching events
etc. So we'll hook 'em up with a client to do just that.  Should work in
multiple environments (node, browser), and do nice things like reconnect,
and hunt through a collection of servers allowing for the removal of the LB
as a logical component.

    EventEmitter  = require('events').EventEmitter
    _             = require 'underscore'

Turns out if you use this in a browser, there's multiple ways you might find
WebSocket, so we go hunting for them.  Either way, if we find one, we're gonna
make it look like an event emitter or at least the way our 'ws' WebSocket
looks.

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

Now that we have a consistent WebSocket to play with

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
