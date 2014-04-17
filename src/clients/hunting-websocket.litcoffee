    log = require 'simplog'
This socket is powerful. So powerful that it will try forever to reconnect to
all the specified servers until you call close. It will not give up. It will not
relent.

OK -- so this socket, on send, will roll through all connected sockets, and the
first one that does a successful transport wins. All connected sockets are
possible sources for incoming messages.

Oh -- and this is a *client side* WebSocket, and is set up to work
with [Browserify](http://browserify.org/). Client side matters since it initiates
the WebSocket connection, so is the only side in a place to reconnect.

If you explicitly call `close()`, then this socket will really close, otherwise
it will work to automatically reconnect `onerror` and `onclose` from the
underlying WebSocket.

#Events
##onserver(event)
This is fired when the active server changes, this will be after a `send` as
that is the only time the socket has activity to 'know' it switched servers.

    ReconnectingWebSocket = require('./reconnecting-websocket.litcoffee')
    WebSocket = WebSocket or require('ws')

    class HuntingWebsocket
      constructor: (@urls) ->
        openAtAll = false
        @lastSocket = undefined
        @sockets = []
        for url in @urls
          socket = new ReconnectingWebSocket(url)
          @sockets.push socket

Event relay. Maybe I should call it *baton* not *evt*. Anyhow, the
`ReconnectingWebSocket` handles the underlying `WebSocket` so we don't need
to hookup each time we reopen.

          socket.onmessage = (evt) =>
            @onmessage evt
          socket.onerror = (err) =>
            @onerror err
          socket.onopen = (evt) =>
            if not openAtAll
              openAtAll = true
              @onopen evt
          socket.onreconnect = (evt) =>
            @onreconnect evt

        @forceclose = false

Send, hunting through every socket until one goes.

      send: (data) ->
        trySockets = @sockets.slice(0)

This is a very simple form of stick preference for the last socket that worked.

        if @lastSocket
          trySockets.unshift @lastSocket

        for socket in trySockets
          try
            if socket.readyState is WebSocket.OPEN
              socket.send(data)
              if socket.url isnt @lastSocket?.url
                @lastSocket = socket
                @onserver server: socket.url
              return
            else
              socket.connect()
          catch err
            @onerror(err)

Close all the sockets.

      close: ->
        for socket in @sockets
          socket.close()
        @onclose()

Empty shims for the event handlers. These are just here for discovery via
the debugger.

      onopen: (event) ->
      onreconnect: (event) ->
      onclose: (event) ->
      onserver: (event) ->
      onmessage: (event) ->
      onerror: (event) ->

Publish this object for browserify.

    module.exports = HuntingWebsocket
