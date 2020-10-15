const path = require('path');
const log = require('simplog');

const {
  ALLOWED_TEMPLATE_PATHS,
  CONNECTION_CONFIG,
  DRIVER_DIRECTORY,
  EPI_SCREAMER_URL,
  ENABLE_TEMPLATE_ACLS,
  HTTP_REQUEST_TIMEOUT_IN_SECONDS,
  NODE_ENV,
  PORT,
  TEMPLATE_CHANGE_FILE,
  TEMPLATE_DIRECTORY,
} = process.env;

const templateDirectory = path.resolve(TEMPLATE_DIRECTORY || path.join(process.cwd(), 'templates'))

let connections;
try {
  connections = JSON.parse(CONNECTION_CONFIG)
}
catch (e) {
  log.error(`Unable to parse CONNECTION_CONFIG env var: ${CONNECTION_CONFIG}`);
  throw e;
}

if (!Object.keys(connections).length) {
  throw new Error('No connections specified');
}

/*
 * transform config to prepare for coming upgrades
 */
Object.keys(connections).forEach(name => {
  const connection = connections[name];

  // this is strictly additive, no modification
  if (connection.config && !connection.config.authentication) {
    connection.config.authentication = {
      type: 'default',
      options: {
        password: connection.config.password,
        userName: connection.config.userName || connection.config.user,
      },
    };
  }
});

module.exports = {
/* if ALLOWED_TEMPLATES exists, it serves as our whitelist for template execution
 * which means any template that is to be allowed to execute must be
 * accounted for in the whitelist.  The white list is expected to be a
 * JSON reprsentation of an object where the properties are names of ALLOWED
 * template directories, and the value must be NOT FALSE so just list allowed
 * template directories
 */
  allowedTemplates: ALLOWED_TEMPLATE_PATHS ? JSON.parse(ALLOWED_TEMPLATE_PATHS) : null,
  connections: connections,
  driverDirectory: DRIVER_DIRECTORY || null,
  enableTemplateAcls: ENABLE_TEMPLATE_ACLS,
  epiScreamerUrl: EPI_SCREAMER_URL,
  forks: Number.parseInt(process.env.FORKS) || 8,
  // default timeout that matches node's HTTP library default and thus matches epiquery1
  httpRequestTimeoutInSeconds: HTTP_REQUEST_TIMEOUT_IN_SECONDS || 120,
  isDevelopmentMode: function() {
    return NODE_ENV !== 'production';
  },
  nodeEnvironment: NODE_ENV || 'development',
  port: PORT || 9090,
  responseTransformDirectory: path.join(templateDirectory, 'response_transforms'),
  templateChangeFile: TEMPLATE_CHANGE_FILE || path.join(templateDirectory, '.change'),
  templateDirectory: templateDirectory,
};
