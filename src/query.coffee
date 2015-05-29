log     = require 'simplog'

queryRequestCounter = 0

execute = (driver, context, cb) ->
  query = context.renderedTemplate
  # this query identifier is used by the client to corellate events from
  # simultaneously executing query requests
  queryId = context.queryId || "#{process.pid}_#{queryRequestCounter++}"
  log.debug(
    "using #{driver.name}, #{queryId} to execute query '#{query}', with connection %j",
    context.connection
  )
  driverInstance = new driver.class(query, context.connection, context)
  context.emit 'beginquery', queryId: queryId
  driverInstance.on 'endquery', () ->
    cb(null, {queryId: queryId})
  driverInstance.on 'beginrowset', () ->
    context.emit 'beginrowset', {queryId: queryId}
  driverInstance.on 'endrowset', (d) ->
    context.emit 'endrowset', {queryId: queryId}
  driverInstance.on 'row', (row) ->
    context.emit 'row', {queryId: queryId, columns: row}
  driverInstance.on 'data', (data) ->
    context.emit 'data', {queryId: queryId, data: data}
  driverInstance.on 'error', (err) -> cb(err, {queryId: queryId})
  driverInstance.execute()

module.exports.execute = execute
