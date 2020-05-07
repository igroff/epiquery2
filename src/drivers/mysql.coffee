events      = require 'events'
mysql       = require 'mysql'
Q           = require 'q'
_           = require 'underscore'

class MySQLDriver extends events.EventEmitter
  constructor: (@query, @config, @context) ->

  execute: () =>
    @config = _.clone @config
    connect_deferred = Q.defer()
    @config.multipleStatements = true
    @isValid = false
    @hasErrored = false

    conn = mysql.createConnection @config
    conn.connect connect_deferred.makeNodeResolver()
    conn.on 'error', (error) => this.emit 'error', error

    connect_deferred.promise.then( () =>
      @isValid = true
      query = conn.query @query
      query.on 'result', (row) => this.emit 'row', row
      query.on 'error',  (error) =>
        @hasErrored = true
        this.emit 'error', error
      query.on 'fields', (fields) => this.emit 'beginrowset', fields
      query.on 'end',    () =>
        # our driver structure really REALLY wants to get EITHER
        # an endquery or an error event and not both. However mysql raises both
        # error and end in the case of an error we avoid the raise of both here
        if not @hasErrored
          this.emit 'endquery'
    ).fail( (error) => this.emit 'error', error
    ).finally( () -> conn.end() )

    
module.exports.DriverClass = MySQLDriver
