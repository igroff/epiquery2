fs          = require 'fs'
LineReader  = require 'line-by-line'
log         = require 'simplog'

queryHandler = (config, filePath, rowCallback, rowSetCallback, cb) ->
  log.debug "file driver handling request for #{filePath}"
  lr = new LineReader(filePath.replace(/\n/,''))
  lr.on 'line', (line) -> rowCallback( {line: line} )
  lr.on 'end', () -> cb()
  lr.on 'error', (err) -> cb(err)
  
module.exports.execute = queryHandler
