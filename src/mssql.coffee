events          = require 'events'
Q               = require 'q'
log             = require 'simplog'
_               = require 'lodash-contrib'
ConnectionPool  = require 'tedious-connection-pool'
tedious         = require 'tedious'
os              = require 'os'

#yes virginia, this won't work on single core machines
#buy a real computer
POOL = {}
poolConfig =
  min: 2
  max: 4
  log: false

class MSSQLDriver extends events.EventEmitter
  constructor: (@query, @connection, @context) ->

  escape: (context) ->
    _.walk.preorder context, (value, key, parent) ->
      if parent
        parent[key] = value.replace(/'/g, "''") if _.isString(value)

  parseQueryParameters: () ->

    lines = @query.match ///^--@.*$///mg

    _.map lines, (line) =>
      line = line.replace '--', ''
      line = line.replace '=', ''

      [varName,type,value] = line.split /\s+/
      varName = varName.replace('@','')
      type = type.replace /\(.*\)/

      value = _.reduce value.split('.'), (doc,prop) ->
        doc[prop]
      , @context.templateContext

      { varName, type, value }

  execute: () =>
    @rowSetStarted = false
    connect_deferred           = Q.defer()
    request_complete_deferred  = Q.defer()

    #connect
    if not POOL[@connection.name]
      POOL[@connection.name] = new ConnectionPool(poolConfig, @connection.config)
    POOL[@connection.name].acquire connect_deferred.makeNodeResolver()

    connect_deferred.promise.then (conn) =>
      request = new tedious.Request @query,
        request_complete_deferred.makeNodeResolver()
      # make sure that no matter how our request-complete event ends, we close
      # the connection
      request_complete_deferred.promise.fin () ->
        conn.release()
      request_complete_deferred.promise.then () =>
        this.emit('endrowset') if @rowSetStarted
        this.emit 'endquery'
      # we use this event to split up multipe result sets as each result set
      # is preceeded by a columnMetadata event
      request.on 'columnMetadata', () =>
        this.emit('endrowset') if @rowSetStarted
        this.emit 'beginrowset'
        @rowSetStarted = true
      request.on 'row', (columns) =>
        this.emit('beginrowset') if not @rowSetStarted
        @rowSetStarted = true
        c = @mapper columns
        this.emit 'row', c

      parameters = @parseQueryParameters()
      unless _.isEmpty parameters
        parameters.forEach (param) ->
          request.addParameter(param.varName, tedious.TYPES[param.type], parseInt(param.value || 0))
        return conn.execSql request

      conn.execSqlBatch request,
        (error) =>
          log.error "[q:#{@context}] connect failed %j", error
          this.emit 'error', error

      Q.all([
        connect_deferred.promise,
        request_complete_deferred.promise
      ]).fail(
        (error) => this.emit 'error', error
      ).done()

module.exports.DriverClass = MSSQLDriver
