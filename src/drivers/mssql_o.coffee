BaseDriver  = require('../mssql.coffee').DriverClass

class MSSQLDriver extends BaseDriver
  constructor: (@query, @config, @context) ->
  # we're _just_ rendering strings to send to sql server so batch is
  # really
  # what we want here, all that fancy parameterization and 'stuff' is
  # done
  # in the template
  mapper: (column) ->
    @[column.metadata.colName] = column.value

module.exports.DriverClass = MSSQLDriver
