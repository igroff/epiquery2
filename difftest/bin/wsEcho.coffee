#! /usr/bin/env coffee

WebSocket     = require 'ws'
global.WebSocket = WebSocket
global.window = {}
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'
clients       = require '../../src/clients/EpiClient.coffee'
optimist      = require 'optimist'

args = optimist.argv

template = args.template
connectionName = args.connection
data = JSON.parse(args.data || "{}")
repeatCount = Number(args.repeat || 1)
SERVER=process.env.EPI_TEST_SERVER || "localhost"
PORT=process.env.PORT || 8080

request =
  connectionName: connectionName
  templateName: template
  data:data
  queryId:"basicSocketQueryId"

ws = new WebSocket("ws://#{SERVER}:#{PORT}/sockjs/websocket")
ws.on('message',
  (data, flags) ->
    console.log(data)
    data = JSON.parse data
    process.exit(0) if data.message == 'endquery'
    process.exit(1) if data.message == 'error'
)
ws.on 'open', () -> ws.send(JSON.stringify request)
