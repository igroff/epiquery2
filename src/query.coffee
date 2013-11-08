QUERY_REQUEST_COUNTER = 0
class QueryRequest
  constructor: (@template, @client, @context=null) ->
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

  sendRow: (row) =>
    event =
      queryId: @id
      message: "row"
      columns: row
    @client.sendEvent 'row', event

  beginRowset: (rowSet) =>
    event =
      queryId: @id
      message: "rowsetBegin"
    @client.sendEvent 'rowsetBegin', event

  endRowset: (rowSet) =>
    event =
      queryId: @id
      message: "rowsetEnd"
    @client.sendEvent 'rowsetEnd', event

  beginQuery: () =>
    @client.sendEvent 'queryBegin', {queryId: @id}

  endQuery: () =>
    @client.sendEvent 'queryEnd', {queryId: @id}
    
 
module.exports.execute = (driver, config, query, rowCallback, rowsetCallback) ->
