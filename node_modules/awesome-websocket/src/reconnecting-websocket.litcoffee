This has the exact same API as
[WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket). So
you get going with:

```
ReconnectingWebSocket = require(reconnecting-websocket)
ws = new ReconnectingWebSocket('ws://...');
```

#Events
##ws
A reference to the contained WebSocket in case you need to poke under the hood.

This may work on the client or the server. Because we love you.

    background = require('./background-process.litcoffee')

    class ReconnectingWebSocket
      constructor: (@url) ->
        @forceClose = false
        @wasConnected = false
        @reconnectAfter = 0
        @connectLoop()

This is the connection retry system. Keep trying at every opportunity.

      connectLoop: () ->
        background =>
          return if @forceClose

          if @readyState isnt WebSocket.OPEN and @readyState isnt WebSocket.CONNECTING
            if Date.now() > @reconnectAfter
              @reconnectAfter = Date.now() + 500
              @connect()

          @connectLoop()

The all powerful connect function, sets up events and error handling.

      connect: () ->
        @readyState = WebSocket.CONNECTING
        @ws = new WebSocket(@url)

        @ws.onmessage = (event) =>
          @onmessage(event)

        @ws.onopen = (event) =>
          @readyState = WebSocket.OPEN
          @wasConnected = true
          @onopen(event)

        @ws.onclose = (event) =>
          @readyState = WebSocket.CLOSED
          @ondisconnect({forceClose: @forceClose}) if @wasConnected
          @onclose(event) if @forceClose

        @ws.onerror = (event) =>
          @readyState = WebSocket.CLOSED
          @onerror(event)

Sending has an odd uncatchable exception, so use marker flags
to know that we did or did not get past a send.

      send: (data) ->
        state = @readyState
        @readyState = WebSocket.CLOSING
        if typeof(data) is "object"
          @ws.send(JSON.stringify(data))
        else
          @ws.send(data)
        @readyState = state

      close: ->
        @forceClose = true
        @ws.close()

Since there's all sorts of ways your connection can be severed if it's not active
( e.g. nginx ), we'll allow you to specify a keep alive message and an interval
on which to send it.
    
      keepAlive: (timeoutMs, message) ->
        sendMessage = () => @send(message)
        setInterval(sendMessage, timeoutMs)

Empty shims for the event handlers. These are just here for discovery via
the debugger.

      onopen: (event) ->
      onclose: (event) ->
      onmessage: (event) ->
      onerror: (event) ->

As a convenience for testing, we'll emit a message when we've disconnected.

      ondisconnect: (event) ->

Publish this object for browserify.

    module.exports = ReconnectingWebSocket
