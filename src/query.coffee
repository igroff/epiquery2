log     = require 'simplog'

queryRequestCounter = 0

execute = (driver, context, cb) ->
  query = context.renderedTemplate
  config = context.connection
  log.debug(
    "using #{driver.name} to execute query '#{query}', with connection %j",
    config
  )
  queryId = context.queryId || +"#{queryRequestCounter++}#{process.pid}"
  context.emit 'beginQuery', queryId: queryId
  driverInstance = new driver.class(query, config.config)
  driverInstance.on 'row', (row) ->
    context.emit 'row', {queryId: queryId, columns: row}
  driverInstance.on 'data', (data) ->
    context.emit 'data', {queryId: queryId, data: data}
  driverInstance.on 'beginRowSet', () ->
    context.emit 'beginRowset', {queryId: queryId}
  driverInstance.on 'endQuery', () -> cb(null, {queryId: queryId})
  driverInstance.on 'error', (err) -> cb(err, {queryId: queryId})

module.exports.execute = execute
