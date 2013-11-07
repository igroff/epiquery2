log     = require 'simplog'

CLIENT_COUNTER=0

class Client
  constructor: (@req, @res) ->
    # we allow people to provide any path relative to the templates directory
    # so we'll remove the initial / and keep the rest of the path while conveniently
    # dropping any parent indicators (..)
    @templatePath = @req.path.replace(/\.\./g, '')
    @id = "#{CLIENT_COUNTER++}#{process.pid}"
    attachClient @req, @res
  sendRow: (row) ->
  startRowset: (metadata=null) ->

  sendData: (data) ->
    @res.write "data: #{data}\n\n"

  sendEvent: (name, data) ->
    @res.write "event: #{name}\n"
    @res.write "data: #{data}\n\n"

  attachClient: () ->
    @req.socket.setTimeout(Infinity)
    @res.writeHead 200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    }
    @res.write('\n')

    registerPing = (client) ->
      sendPing = () -> client.sendData("data: ping\n\n")
      setInterval sendPing, 30000

    registerClose client.id

    client.sendEvent("id_assign", client.id)
    log.debug "attached client: #{client.id}"

module.exports.Client = Client
