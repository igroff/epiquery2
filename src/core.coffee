fs    = require 'fs'
path  = require 'path'
log   = require 'simplog'

loadDrivers = (driverPath=path.join(__dirname, 'src', 'drivers')) ->
  drivers = []
  for file in fs.readdirSync(driverPath)
    driverModule = require path.join(driverPath, file)
    if driverModule.execute
      log.info "loading driver from #{file}"
      drivers.push {driver: driverModule, name: file}
    else
      log.error "Unable to find execute in module #{file}"
  drivers

selectDriver = (templatePath, drivers) ->

module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.selectConnection = (client) ->
