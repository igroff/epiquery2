fs      = require 'fs'
path    = require 'path'
log     = require 'simplog'
config  = require './config.coffee'

DRIVERS=[]

loadDrivers = (driverPath) ->
  log.info "loading drivers from %s", driverPath
  for file in fs.readdirSync(driverPath)
    driverModule = require path.join(driverPath, file)
    if driverModule.execute
      log.info "loading driver from #{file}"
      DRIVERS.push {driver: driverModule, name: file}
    else
      log.error "Unable to find execute in module #{file}"

selectDriver = (templatePath, drivers) ->

module.exports.init = () ->
  loadDrivers(path.join(__dirname, 'drivers'))
  config.driverDirectory and loadDrivers(config.driverDirectory)
  

module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.drivers = DRIVERS
module.exports.selectConnection = (client) ->
