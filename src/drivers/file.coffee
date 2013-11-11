fs          = require 'fs'
LineReader  = require 'line-by-line'

queryHandler = (config, filePath, rowCallback, rowSetCallback, cb) ->
  lr = new LineReader(filePath)
  lr.on 'line', (line) -> rowCallback( {line: line} )
  lr.on 'end', () -> cb()
  lr.on 'error', (err) -> cb(err)
  
module.exports.execute = queryHandler
