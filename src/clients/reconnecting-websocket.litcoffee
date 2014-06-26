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

we try to keep our messasges going for as long as we have any, as a precaution
we check periodically and process any pending messages

        setInterval @processMessageBuffer, 512
  
      connect: () =>

we will ignore connects if we've explicitly been asked to close

        return if @forceClose

cleaning up anything that might keep our WebSocket from being GC

        @ws?.onclose = null
        @ws?.onerror = null
        @ws = new WebSocket(@url)
        @ws.onclose = (event) =>  @onclose(event) if @forceClose
        @ws.onmessage = (event) => @onmessage(event)
        @ws.onerror = (event) => @connect()
        @ws.onopen = (event) =>
          @onopen(event)
          @processMessageBuffer()
  
      processMessageBuffer: () =>
        # we just return if there are no messages to send
        return if @messageBuffer.length is 0
        # first we check to see if we're open, there appears to be a 
        # error raised on send if the socket is not open, this error
        # is uncatchable at the time of this writing, so we check.
        if @ws.readyState is 1 # open
          while message = @messageBuffer.shift()
            try
              @ws.send message
              log.info "message away"
            catch error
              log.error "unable to send message, putting it back on the q"
              @messageBuffer.push message
              @connect()
              break
        else if @ws.readyState is 0 # connecting
          log.error "connecting, waiting"
          return # do nothing, let it connect
        else
          log.error "unexpected ready state #{@ws.readyState}, reconnecting"
          # it's not open so we'll reconnect and let the next pass pick up
          # any messages
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
