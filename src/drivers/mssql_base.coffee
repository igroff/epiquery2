events          = require 'events'
log             = require 'simplog'
_               = require 'lodash-contrib'
tedious         = require 'tedious'
os              = require 'os'

class MSSQLDriver extends events.EventEmitter
  constructor: (@config) ->

  escape: (context) ->
    _.walk.preorder context, (value, key, parent) ->
      if parent
        parent[key] = value.replace(/'/g, "''") if _.isString(value)

  parseQueryParameters: (query, context) ->

    lines = query.match ///^--@.*$///mg

    _.map lines, (line) =>
      line = line.replace '--', ''
      line = line.replace '=', ''

      [varName,type,value] = line.split /\s+/
      varName = varName.replace('@','')
      type = type.replace /\(.*\)/

      value = _.reduce value.split('.'), (doc,prop) ->
        doc[prop]
      , context.templateContext

      { varName, type, value }

  connect: (cb) ->
    @conn = new tedious.Connection @config

    @conn.on 'debug', (message) => log.debug message
    @conn.on 'connect', => (err) ->
      return @emit('error', err) if err
      cb(@)
    @conn.on 'errorMessage', (message) => @emit 'error', message
    @conn.on 'error', (message) => @emit 'error', message

  disconnect: ->
    @conn.close()

  execute: (query, context) =>
    rowSetStarted = false

    request = new tedious.Request query, (err,rowCount) =>
      return @emit('error', err) if err
      @emit('endrowset') if rowSetStarted
      @emit('endquery')

    # we use this event to split up multipe result sets as each result set
    # is preceeded by a columnMetadata event
    request.on 'columnMetadata', () =>
      @emit('endrowset') if rowSetStarted
      @emit('beginrowset')
      rowSetStarted = true

    request.on 'row', (columns) =>
      @emit('beginrowset') if not rowSetStarted
      rowSetStarted = true
      c = _.map(columns, @mapper.bind({}))
      @emit 'row', c

    parameters = @parseQueryParameters(query,context)

    if _.isEmpty parameters
      @conn.execSqlBatch request, (error) =>
        log.error "[q:#{context.queryId}] connect failed %j", error
        @emit 'error', error
    else
      parameters.forEach (param) =>
        request.addParameter(param.varName, tedious.TYPES[param.type], parseInt(param.value || 0))
      @conn.execSql request

module.exports.DriverClass = MSSQLDriver
