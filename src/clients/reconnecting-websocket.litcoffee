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

We're allowing this to work in a browser or not by providing services via
ws if we don't already have a WebSocket

    WebSocket = WebSocket or require('ws')

    class ReconnectingWebSocket
      constructor: (@url) ->
        @forceClose = false
        @messageBuffer = []
        @connect()
        @processMessageBufferInterval
  
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
          @processMessageBuffer()
  
      processMessageBuffer: () =>
        # if you call us, and were not already 'running' we start and return
        # letting the 'normal' path process any messages
        if not @processMessageBufferInterval
          @processMessageBufferInterval =
            setInterval @processMessageBuffer, 128
          return
      
        # first we check to see if we're open, there appears to be a 
        # error raised on send if the socket is not open, this error
        # is uncatchable at the time of this writing, so we check.
        if @ws.readyState is 1 # open
          while message = @messageBuffer.shift()
            try
              @ws.send message
            catch error
              log.debug "unable to send message, putting it back on the q"
              @messageBuffer.push message
              @connect()
              break
        # it's not open so we'll reconnect and let the next pass pick up
        # any messages
        else
          @connect()

      send: (message) =>
        @messageBuffer.push message
        # process messages will either immediately process any messages we have
        # start the 'processMessageBuffer worker' or trigger a reconnect in a
        # more timely manner
        @processMessageBuffer()

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
