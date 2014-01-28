log     = require 'simplog'

queryRequestCounter = 0

execute = (
  driver,
  context,
  beginCallback,
  rowCallback,
  rowsetCallback,
  dataCallback,
cb) ->
  query = context.renderedTemplate
  config = context.connection
  log.debug(
    "using #{driver.name} to execute query '#{query}', with connection %j",
    config
  )
  queryId = context.queryId || +"#{queryRequestCounter++}#{process.pid}"
  beginCallback(queryId: queryId)
  driverInstance = new driver.class(query, config.config)
  driverInstance.on 'row', (row) -> rowCallback {queryId: queryId, columns: row}
  driverInstance.on 'data', (data) -> dataCallback {queryId: queryId, data: data}
  driverInstance.on 'beginRowSet', () -> rowsetCallback {queryId: queryId}
  driverInstance.on 'endQuery', () -> cb null, {queryId: queryId}
  driverInstance.on 'error', (err) -> cb(err, {queryId: queryId})

module.exports.execute = execute
