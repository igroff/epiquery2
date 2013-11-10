fs      = require 'fs'
path    = require 'path'
log     = require 'simplog'
config  = require './config.coffee'

DRIVERS={}

loadDrivers = (driverPath) ->
  log.info "loading drivers from %s", driverPath
  for file in fs.readdirSync(driverPath)
    driverModule = require path.join(driverPath, file)
    if driverModule.execute
      log.info "loading driver from #{file}"
      DRIVERS[file] = {driver: driverModule, name: file}
    else
      log.error "Unable to find execute in module #{file}"

selectDriver = (connectionConfig) ->
  DRIVERS[connectionConfig.driver]

init = () ->
  loadDrivers(path.join(__dirname, 'drivers'))
  config.driverDirectory and loadDrivers(config.driverDirectory)
  
# we select the connection based on the data in the inbound http request
# this allows us to do things like have an explicit override of the connection
# passed in via HTTP Header 
selectConnection = (httpRequest) ->
  conn = req.get "X-DB-CONNECTION"
  if not conn
    templatePath = httpRequest.path.replace(/^\//,'')
    connectionName = templatePath.split('/')[0]
    conn = config.connections[connectionName]

module.exports.init = init
module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.drivers = DRIVERS
module.exports.selectConnection = selectConnection
