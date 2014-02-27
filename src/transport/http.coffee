_       = require 'underscore'
log     = require 'simplog'
path    = require 'path'

attachResponder = (context, res) ->
  nextRowDelim = ""
  haveOneRowSet = nextRowSetDelim = ""
  indent = ""
  stack = []
  increaseIndent = () -> indent = indent + "  "
  decreaseIndent = () -> indent = indent[0...-2]
  ascendOne = () ->
    decreaseIndent()
    stack.shift()()

  c = context
  c.on 'row', (row) ->
    row.message = 'row'
    res.write("#{nextRowDelim}#{indent}#{JSON.stringify(row)}")
    nextRowDelim = ",\n"

  c.on 'beginquery', (d) ->
    increaseIndent()
    res.write "{\n#{indent}\"queryId\":#{d.queryId},\n"
    stack.unshift(() -> res.write "\n#{indent}}\n")
  c.on 'endQuery', () ->
    ascendOne()

  c.on 'beginRowSet', () ->
    if haveOneRowSet
      res.write "#{indent}#{nextRowSetDelim}[\n"
    else
      res.write "#{indent}\"rowsets\":[[\n"
    increaseIndent()
    nextRowDelim = ""
    haveOneRowSet = nextRowSetDelim = ",\n"
  c.on 'endRowSet', () ->
    res.write "\n#{indent}]"

  c.on 'data', (data) ->
    res.write("#{nextRowDelim}#{indent}#{JSON.stringify({data: data})}")
    nextRowDelim = ",\n"

  c.on 'error', (err) ->
    log.error err
    err = err.message if err.message
    res.write "\"error\": \"#{err}\"}"
    res.end()

  c.on 'completeQueryExecution', () ->
    item() while item = stack.shift()
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
    connectionConfig: connection
    params: params
    templateName: templatePath

module.exports.attachResponder = attachResponder
module.exports.getQueryRequestInfo = getQueryRequestInfo
