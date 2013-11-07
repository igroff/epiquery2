log     = require 'simplog'
_       = require 'underscore'

# this is used to create a unique identifier for each client created
# since numbers can be really, really big in v8 and node is single
# threaded in its processing of app code, ther's nothing at all special
# needed for this
CLIENT_COUNTER=0

CONNECTED_CLIENTS={}

class Client
  constructor: (@req, @res) ->
    # we allow people to provide any path relative to the templates directory
    # so we'll remove the initial / and keep the rest of the path while conveniently
    # dropping any parent indicators (..)
    @templatePath = @req.path.replace(/\.\./g, '')
    @id = "#{CLIENT_COUNTER++}#{process.pid}"
    @attach()

  sendRow: (row) ->
  startRowset: (metadata=null) ->

  sendData: (data) ->
    @res.write "data: #{data}\n\n"

  sendEvent: (name, data) ->
    @res.write "event: #{name}\n"
    if data
      @res.write "data: #{data}\n"
    else
      @res.write "data:\n"
    @res.write "\n"

  attach: () =>
    @req.socket.setTimeout(Infinity)
    @res.writeHead 200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive'
    }
    @res.write('\n')

    registerPing = (client) ->
      sendPing = () -> client.sendEvent("ping")
      setInterval sendPing, 5000
  
    # this is how we'll hook the close of the request so that we can do
    # any cleanup of our
    registerClose = (clientId, req) ->
      req.on "close", () ->
        log.debug "close event raised for #{clientId}"
        delete CONNECTED_CLIENTS[clientId]
        num = 0
        _.each CONNECTED_CLIENTS, () -> num++
        log.debug "Num connectedClients connected: #{num}"

    CONNECTED_CLIENTS[@id] = this
    registerClose @id, @req
    registerPing this

    @sendEvent("id_assign", @id)
    log.debug "attached client: #{@id}"


module.exports.Client = Client
module.exports.connectedClients = CONNECTED_CLIENTS
module.exports.getConnectedClientById = (id) -> CONNECTED_CLIENTS[id]
