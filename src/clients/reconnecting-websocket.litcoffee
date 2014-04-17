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
    RECONNECT_TIMEOUT = 3 * 1000

    class ReconnectingWebSocket
      constructor: (@url, reconnectTimeout) ->
        @forceclose = false
        @reconnectTimeout = reconnectTimeout or RECONNECT_TIMEOUT
        @readyState = WebSocket.CONNECTING
        @connectionCount = 0
        @connect()

The all powerful connect function, sets up events and error handling.

      connect: (andSendThis) =>
        @ws = new WebSocket(@url)
        @ws.onopen  =(event) =>
          @readyState = WebSocket.OPEN
          if @connectionCount++
            @onreconnect(event)
          else
            @onopen(event)
          @send(andSendThis) if andSendThis
        @ws.onclose = (event) =>
          if @forceclose
            @readyState = WebSocket.CLOSED
            @onclose(event)
          else
            @readyState = WebSocket.CONNECTING
            setTimeout @connect, @reconnectTimeout
        @ws.onmessage = (event) =>
          @onmessage(event)
        @ws.onerror = (event) =>
          @onerror(event)

      send: (data) ->
        log.info "sending ", data
        try
          @ws.send(data)
        catch error
          @connect(data)

      close: ->
        @forceclose = true
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
