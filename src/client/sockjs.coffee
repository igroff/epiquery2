log     = require 'simplog'
_       = require 'underscore'
path    = require 'path'

attachResponder = (context, conn) ->
  conn.jwrite = (data) =>
    conn.write JSON.stringify(data)
  context.on 'beginQuery', (data) ->
    data.message = 'beginQuery'
    conn.jwrite data
  context.on 'row', (columns) ->
    columns.message = 'row'
    conn.jwrite columns
  context.on 'beginRowSet', () ->
    conn.jwrite message: beginRowset
  context.on 'data', (data) ->
    data.message = 'data'
    conn.jwrite data
  context.on 'error', (err) ->
    # if there's no .message it's gonna need to be a string
    if not err.message
      err.message = err
    conn.jwrite error: err.message.toString()
  context.on 'endQuery', (data) ->
    data.message = "endQuery"
    conn.jwrite data
  context.on 'completeQueryExecution', () ->
    log.debug "close?: #{context.closeOnEnd}"
    if context.closeOnEnd
      conn.close()

module.exports.attachResponder = attachResponder
