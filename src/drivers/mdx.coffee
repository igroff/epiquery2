events      = require 'events'
log         = require 'simplog'
xmla        = require 'xmla4js'

# Need to emit data, error, end, row endquery, beginRowset
class MDXDriver extends events.EventEmitter
  constructor: (@query, @connection) ->
    @config = @connection.config

  execute: () =>
    xmlaRequest =
      async: true
      url: @config.url
      success: (xmla, xmlaRequest, xmlaResponse) =>
        try
          if(!xmlaResponse)
            msg = 'no response for MDX query' + @query
            log.error msg
            this.emit 'error', msg
          else
            obj =  xmlaResponse.fetchAsObject()
            output = obj || {}
            this.emit 'data', JSON.stringify(output)
        catch error
          msg = 'error parsing MDX response: ' + error
          log.error msg
          log.error 'MDX response=' + xmlaResponse
          this.emit 'error', msg
      error: (xmla, xmlaRequest, error) =>
        msg = 'MDX query failed to execute, exception=' + error.message
        log.error msg
        this.emit 'error', msg
      callback: () =>
        this.emit 'endquery'

    xmlaRequest.properties = {}
    xmlaRequest.properties[xmla.Xmla.PROP_CATALOG] = @config.catalog
    xmlaRequest.properties[xmla.Xmla.PROP_FORMAT] = xmla.Xmla.PROP_FORMAT_MULTIDIMENSIONAL
    xmlaRequest.properties[xmla.Xmla.PROP_DATASOURCEINFO] = @config.server
    xmlaRequest.method = xmla.Xmla.METHOD_EXECUTE
    xmlaRequest.statement = @query
    new xmla.Xmla().request(xmlaRequest)

module.exports.DriverClass = MDXDriver
