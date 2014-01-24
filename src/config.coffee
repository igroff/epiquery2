path    = require 'path'
log     = require 'simplog'

# jslint max_line_length: false
###############################################################################
# Configuration:
#   Our configuration information will come from the environment, configuration
#   supports a rich set of options, as such this is a bit tricky.  Information
#   that is required is noted with a * and will be required for the application
#   to function at all.
#
#   CONNECTIONS* - This variable should be a SPACE delimited list of
#     environment varialbes containing connection configuration information
#   <CONNECTION_INFO>* - This is a variable as described by the CONNECTIONS
#     variable, and will contain a JSON object that fully describers a valid
#     connection
#   TEMPLATE_DIRECTORY* - The full path to a directory containing the templates
#     to be used
#   DRIVER_DIRECTORY - Full path to a directory containing additional driver
#     if needed
#
###############################################################################
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
