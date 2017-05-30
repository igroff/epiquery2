events          = require 'events'
log             = require 'simplog'
_               = require 'lodash-contrib'
tedious         = require 'tedious'
os              = require 'os'

lowerCaseTediousTypeMap = {}

# to make it so folks don't have to learn tedious' crazy casing of 
# data types, we'll keep a map of lower cased type names for comparison
# to the inbound parameter type names ( in the case of a parameterized 
# query request )
for propertyName in Object.getOwnPropertyNames(tedious.TYPES)
  type = tedious.TYPES[propertyName]
  lowerCaseTediousTypeMap[type.name.toLowerCase()] = type
  _.forEach type.aliases, (alias) =>
    lowerCaseTediousTypeMap[alias.toLowerCase()] = type

class MSSQLDriver extends events.EventEmitter
  constructor: (@config) ->
    @valid = false

  escapeTemplateContext: (context) ->
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

      # here we can use the unescaped context because
      # parameter values are not subject to the sql injection problems that
      # raw sql is, and our escaping would render parmeter values incorrect e.g.
      # duplicating 's
      value = _.reduce value.split('.'), (doc,prop) ->
        doc[prop]
      , context.unEscapedTemplateContext

      { varName, type, value }

  connect: (cb) ->
    @conn = new tedious.Connection @config

    @conn.on 'debug', (message) => log.debug message
    @conn.on 'connect', (err) =>
      if err
        cb(err)
      else
        @valid = true
        cb(err, @)
    @conn.on 'errorMessage', (message) =>
      log.error "tedious errorMessage: %j", message
      @emit 'errorMessage', message
    @conn.on 'error', (message) =>
      # on error we mark this instance invalid, JIC
      @valid = false
      log.error "tedious error: #{message}"
      @emit 'error', message

  disconnect: ->
    @conn.close()

  validate: ->
    @valid

  invalidate: -> @valid = false

  resetForReleaseToPool: (cb) -> @conn.reset(cb)

  execute: (query, context) =>
    rowSetStarted = false
    # in an attempt to make thing easier to track down on the SQL server side
    # we're going to insert the name of the template that we're executing
    query = "-- #{context.templateName}\n#{query}"
    log.debug "query as sent to server:\n#{query}"
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
      @emit 'row', @mapper(columns)

    parameters = @parseQueryParameters(query,context)

    if _.isEmpty parameters
      @conn.execSqlBatch request, (error) =>
        log.error "[q:#{context.queryId}, t:#{context.templateName}] connect failed %j", error
        @emit 'error', error
    else
      parameters.forEach (param) =>
        lowerCaseTypeName = param.type.toLowerCase()
        tediousType = lowerCaseTediousTypeMap[lowerCaseTypeName]
        log.debug "adding parameter #{param.varName}, value #{param.value} as type #{tediousType.name}"
        request.addParameter(param.varName, tediousType, param.value)
      @conn.execSql request

module.exports.DriverClass = MSSQLDriver
