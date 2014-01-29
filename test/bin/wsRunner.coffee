#! /usr/bin/env coffee

template = process.argv[3]
connectionName = process.argv[2]
data = process.argv[4] || {}
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080
WebSocket = require 'ws'
ws = new WebSocket "ws://#{SERVER}:#{PORT}/sockjs/websocket"
message =
  templateName: template
  connectionName: connectionName
  data: data
  closeOnEnd: true

ws.on 'open', () ->
 console.log "connection established"
 ws.send JSON.stringify(message)
ws.on 'message', (e) -> console.log "got some data #{e}"
ws.on 'close', () -> process.exit 0
