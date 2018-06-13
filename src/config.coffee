path    = require 'path'
log     = require 'simplog'
fs      = require 'fs'

# jslint max_line_length: false
hack_tilde = (path) ->
  path = path.replace(/^~/, process.env.HOME) if path
  return path
TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE = process.env.TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE
TEMPLATE_TO_CONNECTION_MAP = {}
CONNECTION_VAR_NAMES=process.env.CONNECTIONS ||
  throw new Error("No connections specified")
TEMPLATE_DIRECTORY=hack_tilde(process.env.TEMPLATE_DIRECTORY ||
  path.join(process.cwd(), "templates"))
DRIVER_DIRECTORY=hack_tilde(process.env.DRIVER_DIRECTORY) || null
PORT=process.env.PORT || 9090
CONNECTIONS={}
FORKS=Number.parseInt(process.env.FORKS) || 8
FORKS=2 unless FORKS > 0
TEMPLATE_CHANGE_FILE=process.env.TEMPLATE_CHANGE_FILE || path.join(TEMPLATE_DIRECTORY, ".change")
NODE_ENV=process.env.NODE_ENV || "development"
EPISTREAM_API_KEY=process.env.EPISTREAM_API_KEY
URL_BASED_API_KEY=process.env.URL_BASED_API_KEY # use second env var for backwards compatibility
ENABLE_TEMPLATE_ACLS=process.env.ENABLE_TEMPLATE_ACLS
# this is the default timeout that matches node's HTTP library default and thus
# matches epiquery1
HTTP_REQUEST_TIMEOUT_IN_SECONDS=process.env.HTTP_REQUEST_TIMEOUT_IN_SECONDS || 120

# This is how we load our connection configs, the CONNECTION_VAR_NAMES variable contains
# the list of environment variables that specify individual connections, so we split it
# into the consituent names and parse them as JSON
for conn_name in CONNECTION_VAR_NAMES.split(" ")
  try
    conn_o = JSON.parse(process.env[conn_name])
  catch e
    log.error "Unable to parse env var #{conn_name} as connection: #{process.env[conn_name]}"
    throw e
  CONNECTIONS[conn_o.name] = conn_o

# Now we load our template to connection map, this is the structure which can be used
# to define a template specific connection for any given template it overrides any other
# connection selection method
if TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE
  log.info "template to connection map configuration exists, loading from #{TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE}"
  rawTemplateMap = fs.readFileSync(hack_tilde(TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE))
  try
    TEMPLATE_TO_CONNECTION_MAP = JSON.parse(rawTemplateMap)
  catch e
    log.error "Unable to parse template to connection map configuration from #{TEMPLATE_TO_CONNECTION_MAP_CONFIG_FILE}\n#{e}"
else
  log.info "no template to connection map configuration specified, no template based connection routing will be performed"

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
  templateToConnectionMap: TEMPLATE_TO_CONNECTION_MAP

module.exports = config
