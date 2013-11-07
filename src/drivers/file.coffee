fs      = require 'fs'
carrier = require 'carrier'

queryHandler = (config, text, rowCallback, rowSetCallback) ->
  c = carrier.carry fs.createReadableStream(text)
  c.on 'line', (line) -> rowCallback(line)
  
module.exports.execute = queryHandler
