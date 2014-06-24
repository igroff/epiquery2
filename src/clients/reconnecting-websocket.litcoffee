    log = require "simplog"
This has the exact same API as
[WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket). So
you get going with:

```
ReconnectingWebSocket = require(reconnecting-websocket)
ws = new ReconnectingWebSocket('ws://...');
```

#Events
##onreconnect(event)
This callback is fired when the socket reconnects. This is separated from the
`onconnect(event)` callback so that you can have different behavior on the
first time connection from subsequent connections.
##onsend(event)
Fired after a message has gone out the socket.
##ws
A reference to the contained WebSocket in case you need to poke under the hood.

This may work on the client or the server. Because we love you.

    WebSocket = WebSocket or require('ws')

    class ReconnectingWebSocket
      constructor: (@url) ->
        @messageBuffer = []
        @forceClose = false
        @readyState = WebSocket.CONNECTING
        @backoffTimeout = 2
        @connectionCount = 0
        @connect()
        @workQueue()
  
The all powerful connect function, sets up events and error handling.

      connect: (andSendThis) =>
        try
          if @ws
            # null this out because it's the only thing that could
            # keep the socket from being GCd
            @ws.onmessage = null
            @ws.close()
        catch error
          log.debug "cleaning up old socket"
        @ws = new WebSocket(@url)

        @ws.onopen = (event) =>
          @readyState = WebSocket.OPEN
          if @connectionCount++
            @onreconnect(event)
          else
            @onopen(event)

        @ws.onclose = (event) =>
          if @forceClose
            @readyState = WebSocket.CLOSED
            @onclose(event)
          else
            @readyState = WebSocket.CONNECTING

        @ws.onmessage = (event) => @onmessage(event)
        @ws.onerror = (event) => @onerror(event)
  
      workQueue: () =>
        while message = @messageBuffer.shift()
          try
            @ws.send message
            @onsend(sent: message)
          catch error
            log.debug "unable to send message, putting it back on the q"
            @messageBuffer.push message
            @connect()
            break
        setTimeout @workQueue, 128

      send: (data) =>
        @messageBuffer.push data

      close: ->
        @forceClose = true
        @ws.close()

Empty shims for the event handlers. These are just here for discovery via
the debugger.

      onopen: (event) ->
      onclose: (event) ->
      onreconnect: (event) ->
      onmessage: (event) ->
      onerror: (event) ->
      onsend: (event) ->

Publish this object for browserify.

    module.exports = ReconnectingWebSocket
