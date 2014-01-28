log     = require 'simplog'

queryRequestCounter = 0

class QueryRequest
  constructor: (@templateContext, @queryId) ->
    # the id that will be used to relate events to a particular query
    # execution.  This is core to the streaming async nature of the entire
    # system.  The client will be able to issue a number of queries without
    # having to wait for any given one to complete.
    @id = queryRequestCounter++
    # the driver that was selected to handle the execution of the query
    @driver = null
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
 
execute = (
  driver,
  config,
  queryRequest,
  beginCallback,
  rowCallback,
  rowsetCallback,
  dataCallback,
cb) ->
  query = queryRequest.renderedTemplate
  log.debug(
    "using #{driver.name} to execute query '#{query}', with connection %j",
    config
  )
  queryId = queryRequest.queryId || +"#{queryRequestCounter++}#{process.pid}"
  beginCallback(queryId: queryId)
  driverInstance = new driver.class(query, config.config)
  driverInstance.on 'row', (row) -> rowCallback {queryId: queryId, columns: row}
  driverInstance.on 'data', (data) -> dataCallback {queryId: queryId, data: data}
  driverInstance.on 'beginRowSet', () -> rowsetCallback {queryId: queryId}
  driverInstance.on 'endQuery', () -> cb null, {queryId: queryId}
  driverInstance.on 'error', (err) -> cb(err, {queryId: queryId})

module.exports.QueryRequest = QueryRequest
module.exports.execute = execute
