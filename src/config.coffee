path    = require 'path'
log     = require 'simplog'

# jslint max_line_length: false
hack_tilde = (path) ->
  path = path.replace(/^~/, process.env.HOME) if path
  return path

CONNECTION_VAR_NAMES=process.env.CONNECTIONS ||
  throw new Error("No connections specified")
TEMPLATE_DIRECTORY=hack_tilde(process.env.TEMPLATE_DIRECTORY ||
  path.join(process.cwd(), "templates"))
DRIVER_DIRECTORY=hack_tilde(process.env.DRIVER_DIRECTORY) || null
PORT=process.env.PORT || 9090
CONNECTIONS={}

for conn_name in CONNECTION_VAR_NAMES.split(" ")
  try
    conn_o = JSON.parse(process.env[conn_name])
  catch e
    log.error "Unable to parse env var #{conn_name} as connection: #{process.env[conn_name]}"
    throw e
  CONNECTIONS[conn_o.name] = conn_o


config =
  port: PORT
  templateDirectory: TEMPLATE_DIRECTORY
  driverDirectory: DRIVER_DIRECTORY
  connections: CONNECTIONS

module.exports = config
