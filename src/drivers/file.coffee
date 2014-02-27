LineReader  = require 'line-by-line'
events      = require 'events'

class FileDriver extends events.EventEmitter
  constructor: (@filePath) ->

  execute: () =>
    @lineReader = new LineReader(@filePath.replace(/\n/,''))
    @lineReader.on 'line', (line) =>
      this.emit 'data', line
    @lineReader.on 'error', (err) =>
      this.emit 'error', err
    @lineReader.on 'end', () =>
      this.emit 'endQuery'

module.exports.DriverClass = FileDriver
