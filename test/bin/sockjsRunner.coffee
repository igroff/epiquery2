#! /usr/bin/env coffee
jsc = require('sockjs-client')
template=process.argv[2]
data=process.argv[3] || {}
SERVER=process.EPI_TEST_SERVER || "localhost"
PORT=process.PORT || 8080
client = jsc.create("http://#{SERVER}:#{PORT}/sockjs")
client.on('connection', () -> console.log "connection established" )
client.on('data', (e) -> console.log "got some data #{JSON.stringify e}")
client.on('error', (e) -> console.log "error #{e}")
client.on('close', (msg) -> console.log msg ; process.exit 0)

message = {path: template, data:data, closeOnEnd: true}
client.write(JSON.stringify(message))
