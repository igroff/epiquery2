EventEmitter = require('events').EventEmitter
_            = require 'underscore'

class Context extends EventEmitter
  constructor: (props) ->
    _.extend this, props if props

module.exports.Context = Context
