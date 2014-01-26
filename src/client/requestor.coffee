path = require 'path'
_    = require 'underscore'

class Requestor
  getTemplateName: -> throw new Error("Implementation must provide template")
  getConnectionName: -> throw new Error("Impl. Must specify a connection name")
  getConnection: ->

class HttpRequestor extends Requestor
  constructor: (@req, @resp) ->
    # remove any leading '/' and any dubious parent references '..'
    @_templatePath = @req.path.replace(/\.\./g, '').replace(/^\//, '')
    pathParts = @_templatePath.split('/')
    @_connectionName = pathParts.shift()
    @_connection = null
    if @_connectionName is 'header'
      # we allow an inbound connection header to override any other method
      # of selecting a connection
      @_connection = JSON.parse(@req.get('X-DB-CONNECTION') || null)
    @_templatePath = path.join.apply(path.join, pathParts)
    @params = _.extend({}, @req.body, @req.query, @req.headers)
  
  getTemplateName: => @_templatePath
  getConnectionName: => @_connectionName
  getConnection: => @_connection

  respondWith: (response) =>

  send: (message) =>
    message = JSON.stringify(message) if typeof message isnt "string"
    @resp.write message

  sendError: (response) =>
    @send response
    @resp.end()

  dieWith: (resopnse) =>
    @send response
    @resp.end()

class SseRequestor extends HttpRequestor
  respondWith: (response) =>
    @send response

module.exports.HttpRequestor = HttpRequestor
module.exports.SseRequestor = SseRequestor
module.exports.Requestor = Requestor
