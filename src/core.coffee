fs      = require 'fs'
path    = require 'path'
log     = require 'simplog'
config  = require './config.coffee'

DRIVERS={}

loadDrivers = (driverPath) ->
  log.info "loading drivers from %s", driverPath
  for file in fs.readdirSync(driverPath)
    # ignore hidden files
    continue if file[0] is '.'
    driverModule = require path.join(driverPath, file)
    if driverModule.DriverClass
      driverName = file.replace(/\.coffee$/,'').replace(/\.js/,'')
      log.info "loading driver from #{file}"
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
  
# we select the connection based on the data in the inbound http request
# this allows us to do things like have an explicit override of the connection
# passed in via HTTP Header
selectConnection = (httpRequest, queryRequest) ->
  # remove any leading '/' and any dubious parent references '..'
  templatePath = httpRequest.path.replace(/\.\./g, '').replace(/^\//, '')
  # we allow an inbound connection header to override any other method
  # of selecting a connection
  conn = httpRequest.get "X-DB-CONNECTION"
  if not conn
    # the path contains the name of a conneciton as a the first element
    # we'll use that to find the connection and change the request
    # path to a 'real' one
    templatePath = templatePath.replace(/^\//,'')
    pathParts = templatePath.split('/')
    connectionName = pathParts.shift()
    conn = config.connections[connectionName]
    conn || log.error "unable to find connection by name '#{connectionName}'"
    templatePath = path.join.apply(path.join, pathParts)
  queryRequest.templatePath = path.join(config.templateDirectory, templatePath)
  queryRequest.connectionConfig = conn

module.exports.init = init
module.exports.loadDrivers = loadDrivers
module.exports.selectDriver = selectDriver
module.exports.drivers = DRIVERS
module.exports.selectConnection = selectConnection
