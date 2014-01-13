log     = require 'simplog'
_       = require 'underscore'

CONNECTED_CLIENTS={}
CLIENT_COUNTER=0

class Client
  # id is an optional parameter, it's only here to facilitate testing
  constructor: (@req, @res) ->
    @id = "#{CLIENT_COUNTER++}#{process.pid}"
    @attach()

  sendData: (data) =>
    for line in data.split('\n')
      @res.write "data: #{line}\n"
    @res.write "\n"

  sendEvent: (name, data, closeAfterSend=false) =>
    @res.write "event: #{name}\n"
    if data and (typeof(data) is "string")
      for line in data.split('\n')
        @res.write "data: #{line}"
    else if data
      @res.write "data: #{JSON.stringify data}\n"
    else
      # no data
      @res.write "data:\n"
    @res.write "\n"
    if closeAfterSend
      log.debug "closing after sending message %s", name
      @res.end()

  attach: () =>
    @req.socket.setTimeout(Infinity)
    # this is how we'll hook the close of the request so that we can do
    # any cleanup of our
    registerClose = (clientId) =>
      # we're going to use this for our close method on the object
      # so we can close it when the client disconnects or explicitly
      # if called
      this.close = () =>
        log.debug "close event raised for #{clientId}"
        delete CONNECTED_CLIENTS[clientId]
        num = 0
        _.each CONNECTED_CLIENTS, () -> num++
        log.debug "Num connectedClients connected: #{num}"
        @req.removeListener 'close', this.close
        @res.end()
      @req.on 'close', this.close

    CONNECTED_CLIENTS[@id] = this
    registerClose @id, @req

    @sendEvent("id_assign", @id)
    log.debug "attached client: #{@id}"


class Requestor
  constructor: (@req, @resp) ->

  respondWith: (response) =>

  send: (message) =>
    @resp.write message

  dieWith: (response) =>
    @resp.send response

createRequestor = (req, res) -> new Requestor(req, res)

createClient = (req, res) ->
  new Client(req, res)

module.exports.Client = Client
module.exports.connectedClients = CONNECTED_CLIENTS
module.exports.createClient = createClient
module.exports.createRequestor = createRequestor
