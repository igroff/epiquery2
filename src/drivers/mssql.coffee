BaseDriver  = require('../mssql.coffee').DriverClass
_ = require 'lodash-contrib'
class MSSQLDriver extends BaseDriver
  constructor: (@query, @connection, @context) ->
  # we're _just_ rendering strings to send to sql server so batch is
  # really
  # what we want here, all that fancy parameterization and 'stuff' is
  # done
  # in the template
  mapper: (columns) ->
    r = []
    _.each columns, (column) ->
      r.push {value: column.value, name: column.metadata.colName}
    r

module.exports.DriverClass = MSSQLDriver
