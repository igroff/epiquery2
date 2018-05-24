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
FORKS=process.env.FORKS || 8
FORKS=2 unless FORKS > 1
TEMPLATE_CHANGE_FILE=process.env.TEMPLATE_CHANGE_FILE || path.join(TEMPLATE_DIRECTORY, ".change")
NODE_ENV=process.env.NODE_ENV || "development"
EPISTREAM_API_KEY=process.env.EPISTREAM_API_KEY
URL_BASED_API_KEY=process.env.URL_BASED_API_KEY # use second env var for backwards compatibility
ENABLE_TEMPLATE_ACLS=process.env.ENABLE_TEMPLATE_ACLS
# this is the default timeout that matches node's HTTP library default and thus
# matches epiquery1
HTTP_REQUEST_TIMEOUT_IN_SECONDS=process.env.HTTP_REQUEST_TIMEOUT_IN_SECONDS || 120

for conn_name in CONNECTION_VAR_NAMES.split(" ")
  try
    conn_o = JSON.parse(process.env[conn_name])    
  catch e
    log.error "Unable to parse env var #{conn_name} as connection: #{process.env[conn_name]}"
    throw e
  CONNECTIONS[conn_o.name] = conn_o

# if ALLOWED_TEMPLATES exists, it serves as our whitelist for template execution
# which means any template that is to be allowed to execute must be
# accounted for in the whitelist.  The white list is expected to be a
# JSON reprsentation of an object where the properties are names of ALLOWED
# template directories, and the value must be NOT FALSE so just list allowed
# template directories
if process.env.ALLOWED_TEMPLATE_PATHS
  allowedTemplates = JSON.parse(process.env.ALLOWED_TEMPLATE_PATHS)
else
  allowedTemplates = null

config =
  port: PORT
  templateDirectory: TEMPLATE_DIRECTORY
  driverDirectory: DRIVER_DIRECTORY
  connections: CONNECTIONS
  forks: FORKS
  allowedTemplates: allowedTemplates
  templateChangeFile: TEMPLATE_CHANGE_FILE
  responseTransformDirectory: path.join(TEMPLATE_DIRECTORY, 'response_transforms')
  nodeEnvironment: NODE_ENV
  epistreamApiKey: EPISTREAM_API_KEY
  urlBasedApiKey: URL_BASED_API_KEY
  isDevelopmentMode: () -> NODE_ENV isnt "production"
  httpRequestTimeoutInSeconds: HTTP_REQUEST_TIMEOUT_IN_SECONDS
  enableTemplateAcls: ENABLE_TEMPLATE_ACLS
  epiScreamerUrl: process.env.EPI_SCREAMER_URL

module.exports = config
