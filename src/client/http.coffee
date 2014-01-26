_       = require 'underscore'
log     = require 'simplog'
path    = require 'path'

attachResponder = (context, res) ->
    c = context
    res.write '{'
    c.on 'row', (row) -> res.write(JSON.stringify(row))
    c.on 'beginRowSet', () -> res.write '{"rowset":['
    c.on 'data', () -> res.write(JSON.stringify({data: data}))
    c.on 'error', (err) ->
      log.error err
      err = err.message if err.message
      res.write "\"error\": \"#{err}\"}"
      res.end()
    c.on 'completeQueryExecution', () ->
      res.write "]}"
      res.end()

getQueryRequestInfo = (req) ->
    templatePath = req.path.replace(/\.\./g, '').replace(/^\//, '')
    pathParts = templatePath.split('/')
    connectionName = pathParts.shift()
    connection = null
    if connectionName is 'header'
      # we allow an inbound connection header to override any other method
      # of selecting a connection
      connection = JSON.parse(@req.get('X-DB-CONNECTION') || null)
    templatePath = path.join.apply(path.join, pathParts)
    params = _.extend({}, req.body, req.query, req.headers)
    returnThis =
      connectionName: connectionName
      connection: connection
      params: params
      templateName: templatePath

module.exports.attachResponder = attachResponder
module.exports.getQueryRequestInfo = getQueryRequestInfo
