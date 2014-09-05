events      = require 'events'
tedious     = require 'tedious'
Q           = require 'q'
log         = require 'simplog'
_           = require 'lodash-contrib'

class MSSQLDriver extends events.EventEmitter
  constructor: (@query, @config) ->
  
  escape: (context) ->  
    _.walk.preorder context, (value, key, parent) ->
      parent[key] = value.replace(/'/g, "''") if _.isString(value)    

  execute: () =>
    @rowSetStarted = false
    connect_deferred           = Q.defer()
    connect_end_deferred       = Q.defer()
    request_complete_deferred  = Q.defer()

    conn = new tedious.Connection @config
    conn.on 'errorMessage', (infoMessage) -> log.error "te %j", infoMessage
    conn.on 'connect', connect_deferred.makeNodeResolver()
    conn.on 'end', () => connect_end_deferred.resolve()

    connect_deferred.promise.then(
      () =>
        request = new tedious.Request(@query,
          request_complete_deferred.makeNodeResolver())
        # make sure that no matter how our request-complete event ends, we
        # the connection
        request_complete_deferred.promise.fin () ->
          conn.close()
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
          mapper = (column) ->
            {value: column.value, name: column.metadata.colName}
          c = _.map(columns, mapper)
          this.emit 'row', c
        # we're _just_ rendering strings to send to sql server so batch is
        # really
        # what we want here, all that fancy parameterization and 'stuff' is
        # done
        # in the template
        conn.execSqlBatch request,
      (error) =>
        log.error "connect failed %j", error
        this.emit 'error', error
    )

    connect_end_deferred.promise.then(
      () =>
        # this is silly, but... there's a case where tedious will fail to
        # connect but not raise a connect(err) event instead going straight to
        # raising 'end'.  So from the normal processing path, this should be
        # raised by the close of the connection which is done on the request
        # complete trigger and we should then be done anyway so this will simply
        # be redundant
        log.event 'connect_end'
        if connect_deferred.promise.isPending()
          connect_deferred.reject('connection ended prior to sucessful connect')
      ,
      (error) -> log.error "connect end failed #{error}"
    )


    Q.all([
      connect_deferred.promise,
      connect_end_deferred.promise,
      request_complete_deferred.promise
    ]).fail(
      (error) => this.emit 'error', error
    ).done()

module.exports.DriverClass = MSSQLDriver
