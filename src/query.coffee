log     = require 'simplog'

QUERY_REQUEST_COUNTER = 0
class QueryRequest
  constructor: (@client, @context, @closeConnectionOnEndQuery) ->
    # the id that will be used to relate events to a particular query
    # execution.  This is core to the streaming async nature of the entire
    # system.  The client will be able to issue a number of queries without
    # having to wait for any given one to complete.
    @id = QUERY_REQUEST_COUNTER++
    # the driver that was selected to handle the execution of the query
    @driver = null
    @templateContext = {}
    @renderedTemplate = null
    @createdByClientId = null
    # the time the request was received
    @requestReceivedTime = null
    # the time the query execution was started, processing handed off to the
    # driver
    @queryStartTime = null
    # the time the query execution was completed, driver indicated it was
    # done processing the query
    @queryEndTime = null

  sendData: (data) =>
    @client.sendData data

  sendRow: (row) =>
    event =
      queryId: @id
      message: "row"
      columns: row
    @client.sendEvent 'row', event

  sendError: (msg) =>
    event =
      queryId: @id
      message: 'error'
      data: msg
    @client.sendEvent 'error', event

  beginRowset: (rowSet) =>
    event =
      queryId: @id
      message: 'beginRowset'
    @client.sendEvent 'beginRowset', event

  endRowset: (rowSet) =>
    event =
      queryId: @id
      message: 'endRowset'
    @client.sendEvent 'endRowset', event

  beginQuery: () =>
    event =
      queryId: @id
      message: 'beginQuery'
    @client.sendEvent 'beginQuery', event

  endQuery: () =>
    event =
      queryId: @id
      message: 'endQuery'
    @client.sendEvent 'endQuery', event, @closeConnectionOnEndQuery
 
execute = (
  driver,
  config,
  query,
  rowCallback,
  rowsetCallback,
  dataCallback,
cb) ->
  log.debug(
    "using #{driver.name} to execute query #{query}, with connection %j",
    config
  )
  driverInstance = new driver.class(query, config)
  driverInstance.on 'row', rowCallback
  driverInstance.on 'data', dataCallback
  driverInstance.on 'beginRowset', rowsetCallback
  driverInstance.on 'endQuery', cb
  driverInstance.on 'error', cb

module.exports.QueryRequest = QueryRequest
module.exports.execute = execute
