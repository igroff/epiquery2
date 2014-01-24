log     = require 'simplog'
_       = require 'underscore'
HttpRequestor = require('./requestor.coffee').HttpRequestor

class Receiver
  # id is an optional parameter, it's only here to facilitate testing
  constructor: (@req, @res) ->
    @res.write "{\"events\":["
    @responseOpened = false

  sendData: (data) =>
    for line in data.split('\n')
      @res.write "#{line}\n"

  sendEvent: (name, data, closeAfterSend=false) =>
    @res.write "," if @responseOpened
    if data and (typeof(data) is "string")
      for line in data.split('\n')
        @res.write "#{line}\n"
    else if data
      @res.write "#{JSON.stringify data}\n"
    if closeAfterSend
      log.debug "closing after sending message %s", name
      @res.write "]}"
      @res.end()
    @responseOpened = true

createRequestor = (req, res) -> new HttpRequestor(req, res)

module.exports.Client = Receiver
module.exports.createClient = (req, res) -> new Receiver(req, res)
module.exports.createRequestor = createRequestor
