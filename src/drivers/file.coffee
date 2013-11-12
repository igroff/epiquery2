LineReader  = require 'line-by-line'
events      = require 'events'

class FileDriver extends events.EventEmitter
  constructor: (@filePath) ->
    @lineReader = new LineReader(filePath.replace(/\n/,''))
    @lineReader.on 'line', (line) =>
      this.emit 'row', line
    @lineReader.on 'error', (err) =>
      this.emit 'error', err
    @lineReader.on 'end', () =>
      this.emit 'endQuery'
    
module.exports.DriverClass = FileDriver
