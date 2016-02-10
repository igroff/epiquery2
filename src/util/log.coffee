log = require 'simplog'

# allows the caller to force a write of debug log messages, this is to allow
# a specific request to write a debug log messag regardless of the environment
# config
log.debugRequest = debugRequest = (forceDebug, messages, others...) ->
  if forceDebug
    process.env.DEBUG = true
    log.debug(messages, others...)
    delete(process.env.DEBUG)
  else
    log.debug(messages, others...)

module.exports = log

