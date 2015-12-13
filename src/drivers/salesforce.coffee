events      = require 'events'
salesforce  = require 'jsforce'

class SalesforceDriver extends events.EventEmitter

  constructor: (@query, @config) ->

  execute: ->
    conn = new salesforce.Connection({
      loginUrl: @config.server
    })

    conn.login @config.userName, @config.password, (err, userInfo) =>
      return @emit('error', err) if err
      conn.query(@query)
        .on 'record', (record) =>
          @emit 'row', record
        .on 'end', (query) =>
          @emit 'endquery', query
        .on 'error', (error) =>
          @emit 'error', error
        .run { autoFetch: true, maxFetch: @config.maxFetch || 5000 }


module.exports.DriverClass = SalesforceDriver