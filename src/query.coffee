log     = require 'simplog'

queryRequestCounter = 0

execute = (driver, context, cb) ->
  query = context.renderedTemplate
  config = context.connection
  # this query identifier is used by the client to corellate events from
  # simultaneously executing query requests
  queryId = context.queryId || "#{process.pid}_#{queryRequestCounter++}"
  log.debug(
    "using #{driver.name}, #{queryId} to execute query '#{query}', with connection %j",
    config
  )
  driverInstance = new driver.class(query, config.config)
  context.emit 'beginQuery', queryId: queryId
  driverInstance.on 'endQuery', () ->
    cb(null, {queryId: queryId})
  driverInstance.on 'beginRowSet', () ->
    context.emit 'beginRowSet', {queryId: queryId}
  driverInstance.on 'endRowSet', (d) ->
    context.emit 'endRowSet', {queryId: queryId}
  driverInstance.on 'row', (row) ->
    context.emit 'row', {queryId: queryId, columns: row}
  driverInstance.on 'data', (data) ->
    context.emit 'data', {queryId: queryId, data: data}
  driverInstance.on 'error', (err) -> cb(err, {queryId: queryId})
  driverInstance.execute()

module.exports.execute = execute
