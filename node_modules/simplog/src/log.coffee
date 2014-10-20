util    = require 'util'

write = (level, message, formatParams) ->
  if formatParams
    formatParams.unshift message
    if process.env.NOLOGPID or window?
      util.log "[#{level}] #{util.format.apply util.format, formatParams}"
    else
      util.log "[#{process.pid}] [#{level}] #{util.format.apply util.format, formatParams}"
  else
    if process.env.NOLOGPID or window?
      util.log "[#{level}] #{message}"
    else
      util.log "[#{process.pid}] [#{level}] #{message}"

log =
  error: (message, others...) -> write "ERROR", message, others
  info:  (message, others...) -> write "INFO", message, others
  warn:  (message, others...) -> write "WARN", message, others
  debug: (message, others...) ->
    if process.env.DEBUG or window?.debug
      write "DEBUG", message, others
  event: (message, others...) ->
    if process.env.DEBUG or window?.debug
      write "EVENT", message, others

module.exports = log
