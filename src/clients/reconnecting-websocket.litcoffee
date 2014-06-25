    log = require "simplog"
This has the exact same API as
[WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket). So
you get going with:

```
ReconnectingWebSocket = require(reconnecting-websocket)
ws = new ReconnectingWebSocket('ws://...');
```

##ws
A reference to the contained WebSocket in case you need to poke under the hood.

This may work on the client or the server.

    WebSocket = WebSocket or require('ws')

    class ReconnectingWebSocket
      constructor: (@url) ->
        @forceClose = false
        @messageBuffer = []
        @connect()
        @processMessageBufferInterval
  
The all powerful connect function, sets up events and error handling.

      connect: () =>
        try
            # null this out because it's the only thing that could
            # keep the socket from being GCd
            @ws?.onmessage = null
            @ws?.close()
        catch error
          log.error "unexpected error cleaning up old socket #{error}"
        @ws = new WebSocket(@url)

        @ws.onclose = (event) =>  @onclose(event) if @forceClose
        @ws.onmessage = (event) => @onmessage(event)
        @ws.onerror = (event) => @onerror(event)
        @ws.onopen = (event) =>
          @onopen(event)
          @processMessageBufferInterval =
            setInterval @processMessageBuffer, 128

  
      processMessageBuffer: () =>
        if @ws.readyState is 1 # open
          while message = @messageBuffer.shift()
            try
              @ws.send message
            catch error
              log.debug "unable to send message, putting it back on the q"
              @messageBuffer.push message
              @connect()
              break
        else
          @connect()

      send: (message) =>
        @messageBuffer.push message

      close: ->
        @forceClose = true
        @ws.close()

Empty shims for the event handlers. These are just here for discovery via
the debugger.

      onopen: (event) ->
      onmessage: (event) ->
      onclose: (event) ->
      onerror: (event) ->

Publish this object for browserify.

    module.exports = ReconnectingWebSocket
