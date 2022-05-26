fs      = require 'fs'
_       = require 'underscore'
path    = require 'path'
log     = require 'simplog'
config  = require './config.coffee'
events  = require 'events'
buffer  = require './util/buffer.coffee'
templates = require './templates.coffee'
transformer = require './transformer.coffee'

DRIVERS={}
QUERY_EXEC_TIME_STATS={}
QUERIES_EXECUTED={}

loadDrivers = (driverPath) ->
  log.debug "loading drivers from %s", driverPath
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
      log.debug "driver '#{driverName}' loaded"
    else
      log.error "Unable to find execute in module #{file}"

selectDriver = (connectionConfig) ->
  DRIVERS[connectionConfig.driver]

init = () ->
  # load out-of-the-box drivers
  loadDrivers(path.join(__dirname, 'drivers'))
  # load any additional drivers indicated by configuration
  config.driverDirectory and loadDrivers(config.driverDirectory)
  templates.init()
  transformer.init()

trackExecutionTime = (templateName, executionTime) ->
  if QUERY_EXEC_TIME_STATS[templateName] == undefined
    QUERY_EXEC_TIME_STATS[templateName] = new buffer.CircularBuffer(25)
  QUERY_EXEC_TIME_STATS[templateName].store(executionTime)

trackInflightQuery = (templateName) ->
  if not QUERIES_EXECUTED[templateName]
    QUERIES_EXECUTED[templateName] = 0
  QUERIES_EXECUTED[templateName]++

removeInflightQuery = (templateName) ->
  if QUERIES_EXECUTED[templateName]
    QUERIES_EXECUTED[templateName] = QUERIES_EXECUTED[templateName] - 1

getInflightQueries = () ->
  inflightQueries = {}
  _.each QUERIES_EXECUTED, (v, k, l) ->
    inflightQueries[k] = v if v > 0
  return inflightQueries

process.on 'SIGHUP', () ->
  templates.init()
  transformer.init()

process.on 'SIGUSR1', () ->
  #disable ACLs only in development mode
  return unless config.isDevelopmentMode
  log.info 'handling SIGUSR1'
  config.enableTemplateAcls = 'DISABLED'

process.on 'SIGUSR2', () ->
  #enable ACLs only in development mode
  return unless config.isDevelopmentMode
  log.info 'handling SIGUSR2'
  config.enableTemplateAcls = true

module.exports.init = init
module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.drivers = DRIVERS
module.exports.QueryStats = {buffer: new buffer.CircularBuffer(25)}
module.exports.storeQueryExecutionTime = trackExecutionTime
module.exports.getQueryExecutionTimes = QUERY_EXEC_TIME_STATS
module.exports.trackInflightQuery = trackInflightQuery
module.exports.removeInflightQuery = removeInflightQuery
module.exports.getInflightQueries = getInflightQueries
module.exports.events = new events.EventEmitter()
