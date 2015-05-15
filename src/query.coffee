log       = require 'simplog'
{Pool}    = require 'generic-pool'

queryRequestCounter = 0

DRIVER_POOL={}

getDriverInstance = (driver, connectionConfig, driverAquired) ->
  pool = DRIVER_POOL[connectionConfig.name]
  if not pool
    pool = Pool({
      name: connectionConfig.name,
      create: (cb) ->
        log.debug "creating driver instance for connection #{connectionConfig.name}"
        d = new driver.class(connectionConfig.config)
        d.connect(cb)
      destroy: (driver) -> driver.disconnect()
      max: 1
    })
    DRIVER_POOL[connectionConfig.name] = pool
  pool.acquire(driverAquired)

execute = (driver, context, cb) ->
  query = context.renderedTemplate
  config = context.connection
  # if we have a driver that supports pooling, we'll use that
  if typeof(driver.class.prototype.connect) is "function" && typeof(driver.class.prototype.disconnect) is "function"
    # use pooling
    getDriverInstance driver, config, (err, driver) ->
      if err
        message = "unable to acquire driver from pool for connection: #{config.name}"
        log.error message, err
        context.emit 'error', message
      else
        attachAndExecute driver, driver.name, context, cb
  else
    # otherwise we'll new up a driver for each request
    driverInstance = new driver.class(query, config.config, context)
    attachAndExecute driverInstance, driver.name, context, cb

attachAndExecute = (driverInstance, driverName, context, cb) ->
  query = context.renderedTemplate
  # this query identifier is used by the client to corellate events from
  # simultaneously executing query requests
  queryId = context.queryId || "#{process.pid}_#{queryRequestCounter++}"
  log.debug(
    "using #{driverName}, #{queryId} to execute query '#{query}', with connection %j",
    context.connection
  )
  context.emit 'beginquery', queryId: queryId
  driverInstance.on 'endquery', () ->
    pool = DRIVER_POOL[context.connection.name]
    if pool
      pool.release driverInstance
    driverInstance.removeAllListeners 'beginquery'
    driverInstance.removeAllListeners 'beginrowset'
    driverInstance.removeAllListeners 'endrowset'
    driverInstance.removeAllListeners 'row'
    driverInstance.removeAllListeners 'data'
    driverInstance.removeAllListeners 'error'
    driverInstance.removeAllListeners 'endquery'
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
  driverInstance.execute(query, context)

module.exports.execute = execute
