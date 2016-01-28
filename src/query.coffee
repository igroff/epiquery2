log       = require 'simplog'
{Pool}    = require 'generic-pool'

queryRequestCounter = 0

DRIVER_POOL={}

#https://github.com/pekim/tedious/issues/19
#tedious and generic connection pooling is sort of crap

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
      validate: (driver) ->
        # if the driver has a validate method, use it, otherwise we'll
        # mimic the default behavior of the pool wich is to assume good
        log.debug "checking driver validity for connection #{connectionConfig.name}"
        if driver.validate
          return driver.validate()
        else
          return true
      max: 1
    })
    DRIVER_POOL[connectionConfig.name] = pool
  pool.acquire(driverAquired)

execute = (driver, context, cb) ->
  query = context.renderedTemplate
  config = context.connection
  # if we have a driver that supports pooling we'll use pooling, which is defined by a driver
  # having a connect and disconnect method
  if typeof(driver.class.prototype.connect) is "function" && typeof(driver.class.prototype.disconnect) is "function"
    getDriverInstance(driver, config, (err, driver) ->
      if err
        message = "unable to acquire driver from pool for connection: #{config.name}"
        log.error message, err
        cb(new Error(message))
      else
        attachAndExecute driver, context, cb
      )
  else
    # otherwise we'll new up a driver for each request
    driverInstance = new driver.class(query, config.config, context)
    attachAndExecute driverInstance, context, cb

attachAndExecute = (driverInstance, context, cb) ->
  query = context.renderedTemplate
  # this query identifier is used by the client to corellate events from
  # simultaneously executing query requests
  queryId = context.queryId || "#{process.pid}_#{queryRequestCounter++}"
  context.queryId = queryId
  log.debug "using #{context.connection.name}, queryId: #{queryId} to execute query '#{query}', with connection %j", context.connection

  context.emit 'beginquery', queryId: queryId

  endqueryHandler = ->
    pool = DRIVER_POOL[context.connection.name]
    pool.release(driverInstance) if pool

    driverInstance
      .removeListener('beginrowset', beginrowsetHandler)
      .removeListener('endrowset', endrowsetHandler)
      .removeListener('row', rowHandler)
      .removeListener('data', dataHandler)
      .removeListener('error', errorHandler)
      .removeListener('endquery', endqueryHandler)

    cb(null, {queryId: queryId})

  beginrowsetHandler = ->
    context.emit 'beginrowset', {queryId: queryId}

  endrowsetHandler = ->
    context.emit 'endrowset', {queryId: queryId}

  rowHandler = (row) ->
    context.emit 'row', {queryId: queryId, columns: row}

  dataHandler = (data) ->
    context.emit 'data', {queryId: queryId, data: data}

  errorHandler = (err) ->
    log.error "[q:#{context.queryId}] te %j", err
    pool = DRIVER_POOL[context.connection.name]
    pool.destroy(driverInstance) if pool

    cb(err, {queryId: queryId})

  driverInstance
    .on('beginrowset', beginrowsetHandler)
    .on('endrowset', endrowsetHandler)
    .on('row', rowHandler)
    .on('data', dataHandler)
    .on('error', errorHandler)
    .on('endquery', endqueryHandler)

  driverInstance.execute(query, context)

module.exports.execute = execute
