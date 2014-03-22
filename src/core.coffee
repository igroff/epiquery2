fs      = require 'fs'
_       = require 'underscore'
path    = require 'path'
log     = require 'simplog'
config  = require './config.coffee'
events  = require 'events'
buffer  = require './util/buffer.coffee'

DRIVERS={}
QUERY_EXEC_TIME_STATS={}
QUERIES_IN_FLIGHT={}

loadDrivers = (driverPath) ->
  log.info "loading drivers from %s", driverPath
  for file in fs.readdirSync(driverPath)
    # ignore hidden files
    continue if file[0] is '.'
    log.debug "loading driver from #{file}"
    driverModule = require path.join(driverPath, file)
    if driverModule.DriverClass
      driverName = file.replace(/\.coffee$/,'').replace(/\.js/,'')
      DRIVERS[driverName] =
        class: driverModule.DriverClass
        module: driverModule
        name: driverName
      log.info "driver '#{driverName}' loaded"
    else
      log.error "Unable to find execute in module #{file}"

selectDriver = (connectionConfig) ->
  DRIVERS[connectionConfig.driver]

init = () ->
  # load out-of-the-box drivers
  loadDrivers(path.join(__dirname, 'drivers'))
  # load any additional drivers indicated by configuration
  config.driverDirectory and loadDrivers(config.driverDirectory)

trackExecutionTime = (templateName, executionTime) ->
  if QUERY_EXEC_TIME_STATS[templateName] == undefined
    QUERY_EXEC_TIME_STATS[templateName] = new buffer.CircularBuffer(25)
  QUERY_EXEC_TIME_STATS[templateName].store(executionTime)
  
module.exports.init = init
module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.drivers = DRIVERS
module.exports.QueryStats = {buffer: new buffer.CircularBuffer(25)}
module.exports.storeQueryExecutionTime = trackExecutionTime
module.exports.getQueryExecutionTimes = QUERY_EXEC_TIME_STATS
module.exports.events = new events.EventEmitter()
