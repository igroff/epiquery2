_       = require 'underscore'
log     = require 'simplog'
path    = require 'path'


attachResponder = (context, res) ->
  if context.responseFormat is 'resty'
    attachSimpleResponder(context, res)
  else if context.responseFormat is 'epiquery1'
    attachEpiqueryResponder(context, res)
  else
    attachStandardResponder(context, res)

attachEpiqueryResponder = (context, res) ->
  status = 200
  responseData = []
  resultElementDelimiter = ""
  responseObjectDelimiter = ""
  stack = []
  responseData.push "["

  completeResponse = () ->
    responseData.push "]"
    res
      .status(status)
      .header('Content-Type', 'application/javascript')
      .end(responseData.join(''))

  writeResultElement = (obj) ->
    responseData.push "#{resultElementDelimiter}#{JSON.stringify obj}"
    resultElementDelimiter = ","

  writeResponseObjectElement = (str) ->
    responseData.push "#{responseObjectDelimiter}#{str}"

  context.on 'row', (row) ->
    delete(row['queryId'])
    columns = {}
    _.map(row.columns, (e, i, l) -> columns[l[i].name || 'undefiend'] = l[i].value)
    writeResultElement columns

  context.on 'beginrowset', (d={}) ->
    writeResponseObjectElement "["
    responseObjectDelimiter = ""
    resultElementDelimiter = ""

  context.on 'endrowset', (d={}) ->
    writeResponseObjectElement "]"
    responseObjectDelimiter = ","

  context.on 'data', (data) ->
    writeResultElement data

  context.on 'error', (err) ->
    d = message: 'error', errorDetail: err
    d.error = err.message if err.message
    log.error err
    status = 500
    writeResultElement d

  context.once 'completequeryexecution', completeResponse
attachSimpleResponder = (context, res) ->
  status = 200
  responseData = []
  resultElementDelimiter = ""
  responseObjectDelimiter = ""
  stack = []
  responseData.push "{\"results\":["

  completeResponse = () ->
    responseData.push "]}"
    res
      .status(status)
      .header('Content-Type', 'application/javascript')
      .end(responseData.join(''))

  writeResultElement = (obj) ->
    responseData.push "#{resultElementDelimiter}#{JSON.stringify obj}"
    resultElementDelimiter = ","

  writeResponseObjectElement = (str) ->
    responseData.push "#{responseObjectDelimiter}#{str}"

  context.on 'row', (row) ->
    delete(row['queryId'])
    columns = {}
    _.map(row.columns, (e, i, l) -> columns[l[i].name || 'undefiend'] = l[i].value)
    writeResultElement columns

  context.on 'beginrowset', (d={}) ->
    writeResponseObjectElement "["
    responseObjectDelimiter = ""
    resultElementDelimiter = ""

  context.on 'endrowset', (d={}) ->
    writeResponseObjectElement "]"
    responseObjectDelimiter = ","

  context.on 'data', (data) ->
    writeResultElement data

  context.on 'error', (err) ->
    d = message: 'error', errorDetail: err
    d.error = err.message if err.message
    log.error err
    status = 500
    writeResultElement d

  context.once 'completequeryexecution', completeResponse

attachStandardResponder = (context, res) ->
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
  if pathParts[0] is 'resty'
    transport = pathParts.shift()
  else if pathParts[0] is 'epiquery1'
    transport = pathParts.shift()
  else
    transport = 'standard'

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
    responseFormat: transport

module.exports.attachResponder = attachResponder
module.exports.getQueryRequestInfo = getQueryRequestInfo
