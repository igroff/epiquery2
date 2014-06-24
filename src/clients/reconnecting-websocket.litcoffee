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
        @forceClose = false
        @reconnectTimeout = 2
        @readyState = WebSocket.CONNECTING
        @connectionCount = 0
        @connect()

The all powerful connect function, sets up events and error handling.

      connect: (andSendThis) =>
        @ws = new WebSocket(@url)
        @ws.onopen = (event) =>
          @reconnectTimeout = 2
          @readyState = WebSocket.OPEN
          if @connectionCount++
            @onreconnect(event)
          else
            @onopen(event)
          @send(andSendThis) if andSendThis
        @ws.onclose = (event) =>
          if @forceClose
            @readyState = WebSocket.CLOSED
            @onclose(event)
          else
            @readyState = WebSocket.CONNECTING
            @reconnectTimeout = Math.pow(@reconnectTimeout, 2)
            setTimeout @connect, @reconnectTimeout
        @ws.onmessage = (event) =>
          @onmessage(event)
        @ws.onerror = (event) =>
          @onerror(event)

      send: (data) =>
        sender = =>
          try
              @ws.send(data)
              @onsend(data)
          catch error
            @connect(data)
        setTimeout sender, 0

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
