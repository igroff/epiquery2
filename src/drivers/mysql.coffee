events      = require 'events'
mysql       = require 'mysql'
Q           = require 'q'
_           = require 'underscore'

class MySQLDriver extends events.EventEmitter
  constructor: (@query, @config, @context) ->

  parseQueryParameters: (query, context, userDefinedVariablesValues) ->

    lines = query.match ///^set\s*@.*\s*=\s*\?\;$///mg

    _.map lines, (line) =>
      line = line.replace '#--', ''
      line = line.replace '=', ''
      line = line.replace 'set ', ''
      line = line.replace '?', ''
      line = line.replace ';', ''

      [varName,value] = line.split /\s+/
      varName = varName.replace('@','')
      type = type?.replace /\(.*\)/

      # as a convenience, we'll let you omit the value declaration in which case we'll use the name of the parametr
      # as the name of the value
      value = varName unless value

      # here we can use the unescaped context because
      # parameter values are not subject to the sql injection problems that
      # raw sql is, and our escaping would render parmeter values incorrect e.g.
      # duplicating 's
      value = _.reduce value.split('.'), (doc,prop) ->
        doc[prop]
      , context.unEscapedTemplateContext

      userDefinedVariablesValues.push(value)

      { varName, type, value }


  execute: () =>

    userDefinedVariablesValues = []
    parameters = @parseQueryParameters(@query, @context, userDefinedVariablesValues)

    rowSetStarted = false

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

      query = conn.query @query, userDefinedVariablesValues
      query.on 'result', (row) => 
        
        if row.constructor.name == 'RowDataPacket'
          this.emit 'row', row
        
      query.on 'error',  (error) =>
        if rowSetStarted
          this.emit 'endrowset'           
          this.emit 'beginrowset'
        @hasErrored = true
        this.emit 'error', error
      query.on 'fields', (fields) => 
        
        this.emit 'endrowset', fields if rowSetStarted
        rowSetStarted = true if not rowSetStarted         
        this.emit 'beginrowset', fields
        
      query.on 'end',    () =>
        # our driver structure really REALLY wants to get EITHER
        # an endquery or an error event and not both. However mysql raises both
        # error and end in the case of an error we avoid the raise of both here
        if not @hasErrored
          this.emit 'endrowset'          
          this.emit 'endquery'
    ).fail( (error) => this.emit 'error', error
    ).finally( () -> conn.end() )

    
module.exports.DriverClass = MySQLDriver
