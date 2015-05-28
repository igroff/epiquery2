_       = require 'underscore'
log     = require 'simplog'
path    = require 'path'

attachResponder = (context, res) ->
  delim = ""
  indent = ""
  stack = []
  increaseIndent = () -> indent = indent + "  "
  decreaseIndent = () -> indent = indent[0...-2]

  c = context
  res.header 'Content-Type', 'application/javascript'
  res.write "{\n  \"events\":[\n"
  stack.unshift( () -> res.write "\n#{indent}]\n}\n" )
  increaseIndent()

  completeResponse = () ->
    item() while item = stack.shift()
    res.end()

  writeEvent = (evt) ->
    res.write "#{delim}#{indent}#{JSON.stringify evt}"
    delim = ",\n"

  c.on 'row', (row) ->
    row.message = 'row'
    writeEvent row

  c.on 'beginquery', (d={}) ->
    d.message = 'beginquery'
    writeEvent d

  c.on 'endquery', (d={}) ->
    d.message = 'endquery'
    writeEvent d

  c.on 'beginrowset', (d={}) ->
    d.message = 'beginrowset'
    writeEvent d

  c.on 'endrowset', (d={}) ->
    d.message = 'endrowset'
    writeEvent d

  c.on 'data', (data) ->
    data.message = 'data'
    writeEvent data

  c.on 'error', (err) ->
    d = message: 'error', errorDetail: err
    d.error = err.message if err.message
    log.error err
    writeEvent d

  c.once 'completequeryexecution', completeResponse

getQueryRequestInfo = (req, useSecure) ->
  templatePath = req.path.replace(/\.\./g, '').replace(/^\//, '')
  pathParts = templatePath.split('/')
  # If we're using a key secured client, the key must be before the connection name
  if useSecure
    clientKey = pathParts.shift()
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
    connectionConfig: connection
    templateContext: params
    templateName: templatePath
    clientKey: clientKey

module.exports.attachResponder = attachResponder
module.exports.getQueryRequestInfo = getQueryRequestInfo
