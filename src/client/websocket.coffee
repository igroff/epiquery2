log     = require 'simplog'
_       = require 'underscore'
path    = require 'path'
Requestor = require('./requestor.coffee').Requestor

class Receiver
  # id is an optional parameter, it's only here to facilitate testing
  constructor: (@socketConnection) ->

  sendData: (data) =>
    log.debug " [ws] sending to client #{data}"
    @socketConnection.write(data) if typeof data is "string"

  sendEvent: (name, data, closeAfterSend=false) =>
    event = {name: name}
    if data
      event.data = data
    @socketConnection.write JSON.stringify(data)
    if closeAfterSend
      log.debug "closing after sending message %s", name
      @socketConnection.close(0, "I've been asked to close you")

class WebSocketRequestor extends Requestor
  constructor: (@socketConnection, @message) ->
    # remove any leading '/' and any dubious parent references '..'
    @_templatePath = @message.path.replace(/\.\./g, '').replace(/^\//, '')
    pathParts = @_templatePath.split('/')
    # specifying connection name overrides it
    @_connectionName = message.connectionName || pathParts.shift()
    @_connection = null
    @_templatePath = path.join.apply(path.join, pathParts)
    @params = @message
  
  getTemplateName: => @_templatePath
  getConnectionName: => @_connectionName
  getConnection: => @_connection

  respondWith: () ->
  send: (message) =>
    log.debug " [ws] sending #{message}"
    @socketConnection.write message if typeof message is "string"

  sendError: (message) =>
    log.debug " [ws] sending #{message}"
    @socketConnection.write message if typeof message is "string"

  dieWith: (message) =>
    log.debug " [ws] sending #{message}"
    @socketConnection.write message if typeof message is "string"

createRequestor = (req, res) -> new WebSocketRequestor(req, res)

attachResponder = (context, conn) ->
  conn.jwrite = (data) =>
    conn.write JSON.stringify(data)
  context.on 'beginQuery', (data) ->
    data.message = 'beginQuery'
    conn.jwrite data
  context.on 'row', (columns) ->
    columns.message = 'row'
    conn.jwrite columns
  context.on 'beginRowSet', () ->
    conn.jwrite message: beginRowset
  context.on 'data', (data) ->
    data.message = 'data'
    conn.jwrite data
  context.on 'error', (err) ->
    # if there's no .message it's gonna need to be a string
    if not err.message
      err.message = err
    conn.jwrite error: err.message.toString()
  context.on 'endQuery', (data) ->
    data.message = "endQuery"
    conn.jwrite data
  context.on 'completeQueryExecution', () ->
    log.debug "close?: #{context.closeOnEnd}"
    if context.closeOnEnd
      conn.close()

module.exports.Client = Receiver
module.exports.createClient = (conn) -> new Receiver(conn)
module.exports.createRequestor = createRequestor
module.exports.attachResponder = attachResponder
