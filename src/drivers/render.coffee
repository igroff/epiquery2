events      = require 'events'

class RenderOnlyDriver extends events.EventEmitter
  constructor: (@query, @config) ->
  
  execute: () =>
    this.emit 'data', @query
    this.emit 'endQuery'

    
module.exports.DriverClass = RenderOnlyDriver
