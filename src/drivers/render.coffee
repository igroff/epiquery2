events      = require 'events'

class RenderOnlyDriver extends events.EventEmitter
  constructor: (@query, @config) ->
    process.nextTick () => this.emit 'data', @query
    process.nextTick () => this.emit 'endQuery'
    
module.exports.DriverClass = RenderOnlyDriver
