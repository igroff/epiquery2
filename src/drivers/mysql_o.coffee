events      = require 'events'
mysql       = require 'mysql'
Q           = require 'q'
_           = require 'underscore'

class MySQLDriver extends events.EventEmitter
  constructor: (@query, @config) ->

  execute: () =>
    @config = _.clone @config
    connect_deferred = Q.defer()
    @config.multipleStatements = true

    conn = mysql.createConnection @config
    conn.connect connect_deferred.makeNodeResolver()
    conn.on 'error', (error) => this.emit 'error', error

    connect_deferred.promise.then( () =>
      query = conn.query @query
      query.on 'result', (row) => this.emit 'row', row
      query.on 'error',  (error) => this.emit 'error', error
      query.on 'fields', (fields) => this.emit 'beginrowset', fields
      query.on 'end',    () => this.emit 'endquery'
    ).fail( (error) => this.emit 'error', error
    ).finally( () -> conn.end() )

    
module.exports.DriverClass = MySQLDriver
