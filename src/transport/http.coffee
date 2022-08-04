_       = require 'underscore'
log     = require 'simplog'
path    = require 'path'
fs      = require 'fs'
getRequestedTransform = require('../transformer.coffee').getRequestedTransform


attachResponder = (context, res) ->
  if context.responseFormat is 'simple'
    attachSimpleResponder(context, res)
  else if context.responseFormat is 'epiquery1'
    attachEpiqueryResponder(context, res)
  else if context.responseFormat is 'transform'
    attachTransformationResponder(context, res)
  else if context.responseFormat is 'csv'
    attachCSVResponder(context, res)
  else # the original format, matching the socket protocol
    attachStandardResponder(context, res)

attachTransformationResponder = (context, res) ->
  currentRowset = null
  # response will always contain rowsets, even if they are
  # empty, however it can optionally contain errors and data
  # elements depending on how things go and what was requested
  response =
    rowSets: []
    # errors: []
    # data: []

  completeResponse = () ->
    context.response = response
    log.debug "response context:\n %j", context
    log.debug "using response transform #{context.responseTransform}"
    getRequestedTransform context.responseTransform, (err, transform) ->
      if err
        log.error "error loading response transform\n#{err}"
        res.status(500).send(error: "error loading requested response transform #{context.responseTransform}").end()
      else
        try
          transformedResponse = transform(context.response)
          res
            .status(200)
            .header('Content-Type', 'application/javascript')
            .send(transformedResponse)
            .end()
        catch e
          log.error "error during transformation of response\n #{e.stack}"
          res.status(500).send(error: "error during transformation of response #{e.message}").end()

  context.on 'row', (row) ->
    currentRowset.push(row.columns)

  context.on 'beginrowset', (d={}) ->
    currentRowset = []

  context.on 'endrowset', (d={}) ->
    response.rowSets.push(currentRowset)
    currentRowset = null

  context.on 'data', (data) ->
    response.data?.push(data) ? response.data = [data]

  context.on 'error', (err) ->
    if err
      response.errors?.push(err) ? response.errors = [err]

  context.once 'completequeryexecution', completeResponse

attachEpiqueryResponder = (context, res) ->
  status = 200
  rowSetCount = 0
  responseData = []
  resultElementDelimiter = ""
  responseObjectDelimiter = ""
  didBeginRowSet = false
  stack = []

  completeResponse = () ->
    # epiquery "helpfully" sent only one array in the case tat the query
    # contained only a single result set, otherwise it returned an array of
    # arrays.  So we'll only make the response and array of arrays if we
    # have more than a single resultSet
    if rowSetCount > 1
      responseData.unshift "["
      responseData.push "]"
    res
      .status(status)
      .header('Content-Type', 'application/json')
      .end(responseData.join(''))

  writeResultElement = (obj) ->
    responseData.push "#{resultElementDelimiter}#{JSON.stringify obj}"
    resultElementDelimiter = ","

  writeResponseObjectElement = (str) ->
    responseData.push "#{responseObjectDelimiter}#{str}"

  context.on 'row', (row) ->
    delete(row['queryId'])
    columns = {}
    # this is a bit gruesome, unfortunately, the underlying driver can either return
    # an array of objects, or an array of name/value pairs
    if _.isArray(row.columns)
      _.map(row.columns, (v, i, l) -> columns[l[i].name || 'undefined'] = l[i].value)
    else
      _.map(row.columns, (v, k, o) -> columns[k || 'undefined'] = v)
    writeResultElement columns

  context.on 'beginrowset', (d={}) ->
    writeResponseObjectElement "["
    didBeginRowSet = true
    responseObjectDelimiter = ""
    resultElementDelimiter = ""
    rowSetCount += 1

  context.on 'endrowset', (d={}) ->
    writeResponseObjectElement "]"
    responseObjectDelimiter = ","

  context.on 'data', (data) ->
    writeResultElement data

  context.on 'error', (err) ->
    d = message: 'error', errorDetail: err
    d.error = err.message if err.message
    # by the time we get here, the error has been logged elsewhere so
    # this is really just for debugging
    log.debug err
    status = 500
    writeResultElement d
    #check if we hit beginrowset - if so add a closing ']' since we won't hit endrowset
    #and only if we hit beginroset because it is possible an error occurs prior to getting there.
    if didBeginRowSet then writeResponseObjectElement ']'

  context.once 'completequeryexecution', completeResponse

attachCSVResponder = (context, res) ->
  didWriteHeaders = false
  res.status(200)
  res.header('Content-Type', 'application/javascript')

  completeResponse = () ->
    res.end()

  writeCSVRow = (columnNames, values) ->
    # if we have not yet written our headers for this result set
    # write them
    if not didWriteHeaders
      # track the first item so that we can write out commas as needed
      firstItem = true
      _.map(columnNames, (v,k,_) ->
        res.write(",") unless firstItem
        res.write("\"#{v}\"")
        firstItem = false
      )
      res.write("\n")
      didWriteHeaders = true
    # write out our values, tracking the first value so that we can
    # appropriately add commas
    firstValue = true
    _.map(values, (v,k,_) ->
      res.write(",") unless firstValue
      firstValue = false
      if typeof(v) is "string"
        res.write("\"#{v.replace(/"/g, '""')}\"")
      else if v is null
        return
      else
        res.write("#{v}")
    )
    res.write("\n")

  context.on 'row', (row) ->
    delete(row['queryId'])
    columnNames = []
    values = []
    # this is a bit gruesome, unfortunately, the underlying driver can either return
    # an array of objects, or an array of name/value pairs
    if _.isArray(row.columns)
      _.map(row.columns, (v, i, l) ->
        columnNames.push(l[i].name || 'undefined')
        values.push(l[i].value)
      )
    else
      # this is sort of a best attempt here, because the underlying driver will eat
      # identically named columns, so the output from this path will only be as good
      # as the underlying driver
      _.map(row.columns, (v, k, o) ->
        columnNames.push(k || 'undefined')
        values.push(v)
      )
    writeCSVRow columnNames, values

  context.on 'beginrowset', () ->
    didWriteHeaders = false

  context.on 'endrowset', () ->
    res.write "\n"

  context.on 'error', (err) ->
    log.error "Error during generation of CSV response: #{err}"
    status = 500
    res.write "An error occurred: #{err}"

  context.once 'completequeryexecution', completeResponse

attachSimpleResponder = (context, res) ->
  status = 200
  responseData = []
  resultElementDelimiter = ""
  responseObjectDelimiter = ""
  didBeginRowSet = false
  stack = []
  res.status(200)
  res.header('Content-Type', 'application/javascript')

  completeResponse = () ->
    responseObjectDelimiter = ""
    writeResponseObjectElement "]}"
    res.end()

  writeResultElement = (obj) ->
    res.write "#{resultElementDelimiter}#{JSON.stringify obj}"
    resultElementDelimiter = ","

  writeResponseObjectElement = (str) ->
    res.write "#{responseObjectDelimiter}#{str}"

  context.on 'row', (row) ->
    delete(row['queryId'])
    columns = {}
    # this is a bit gruesome, unfortunately, the underlying driver can either return
    # an array of objects, or an array of name/value pairs
    if _.isArray(row.columns)
      _.map(row.columns, (v, i, l) -> columns[l[i].name || 'undefined'] = l[i].value)
    else
      _.map(row.columns, (v, k, o) -> columns[k || 'undefined'] = v)
    writeResultElement columns

  context.on 'beginrowset', (d={}) ->
    writeResponseObjectElement "["
    didBeginRowSet = true
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
    # by the time we get here, the error has been logged elsewhere so
    # this is really just for debugging
    log.debug err
    status = 500
    writeResultElement d
    #check if we hit beginrowset - if so add a closing ']' since we won't hit endrowset
    #and only if we hit beginroset because it is possible an error occurs prior to getting there.
    if didBeginRowSet then writeResponseObjectElement ']'

  context.once 'completequeryexecution', completeResponse

  # open our response. no matter what, we're gonna write a json response
  # and our return will be 200 with any actual information about the query provided
  # within the response JSON structure
  writeResponseObjectElement "{\"results\":["

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
    # by the time we get here, the error has been logged elsewhere so
    # this is really just for debugging
    log.debug err
    writeEvent d

  c.once 'completequeryexecution', completeResponse


getQueryRequestInfo = (req) ->
  templatePath = req.path.replace(/\.\./g, '').replace(/^\//, '')
  pathParts = templatePath.split('/')

  # pick out any requested response formats
  if pathParts[0] is 'epiquery1'
    format = pathParts.shift()
  else if pathParts[0] is 'csv'
    format = pathParts.shift()
  else if req.query['transform']
    format = 'transform'
    transformName = req.query['transform']
  else if pathParts[0] is 'simple'
    format = pathParts.shift()
  else
    format = 'standard'

  connectionName = pathParts.shift()
  connection = null
  if connectionName is 'header'
    # we allow an inbound connection header to override any other method
    # of selecting a connection
    connection = JSON.parse(@req.get('X-DB-CONNECTION') || null)
  templatePath = path.join.apply(path.join, pathParts)
  returnThis =
    connectionName: connectionName
    connectionConfig: connection
    templateContext: _.extend({}, req.body, req.query, req.headers)
    templateName: templatePath
    responseFormat: format
    responseTransform: transformName
    debug: req.query.debug is "true"
    requestHeaders: req.headers || {}

module.exports.attachResponder = attachResponder
module.exports.getQueryRequestInfo = getQueryRequestInfo
