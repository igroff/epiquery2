events      = require 'events'
salesforce  = require 'jsforce'
log         = require 'simplog'

class SalesforceDriver extends events.EventEmitter

  constructor: (@config) ->

  execute: (query, context) ->
      log.debug "executing SOQL query #{query}"
      @conn.query(query)
        .on 'record', (record) =>
          @emit 'row', record
        .on 'end', (query) =>
          @emit 'endquery', query
        .on 'error', (error) =>
          @emit 'error', error
        .run { autoFetch: true, maxFetch: @config.maxFetch || 5000 }

  connect: (cb) ->
    log.debug "connecting sfdc %j", @config
    @conn = new salesforce.Connection({ loginUrl: @config.server })
    @conn.login @config.userName, @config.password, (err) =>
      log.debug "got something #{@}"
      cb(err, @)

  # do nothing, but we need this so we can be pooled
  disconnect: ->

module.exports.DriverClass = SalesforceDriver
