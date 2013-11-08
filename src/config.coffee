rc      = require 'rc'
path    = require 'path'

APP_NAME="epiquery2"

CONFIG_DIR=__dirname
if process.env.HOME
  CONFIG_DIR=path.join(process.env.HOME, ".#{APP_NAME}")

DEFAULTS=
  port: 9090
  templateDirectory: path.join(CONFIG_DIR, "templates")
  driverDirectory: null

module.exports = rc 'epiquery2', DEFAULTS
