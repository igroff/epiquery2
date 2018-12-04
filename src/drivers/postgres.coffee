events      = require 'events'
pg          = require 'pg'
_           = require 'underscore'

class PostgresDriver extends events.EventEmitter
  constructor: (@query, @config, @context) ->

  execute: () =>
    @config = _.clone @config
    conString = "postgres://#{@config.userName}:#{@config.password}@#{@config.server}/#{@config.databaseName}";
    pg.connect conString, (err, client, done) =>
      @emit 'error', err if err
      query = client.query @query
      query.on 'row', (row) => @emit 'row', row
      query.on 'error',  (error) => @emit 'error', error
      query.on 'end',    () => @emit 'endquery'
      done()
    
module.exports.DriverClass = PostgresDriver
