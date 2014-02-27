events      = require 'events'

class RenderOnlyDriver extends events.EventEmitter
  constructor: (@query, @config) ->
    setImmediate () => this.emit 'data', @query
    setImmediate () => this.emit 'endQuery'

    
module.exports.DriverClass = RenderOnlyDriver
