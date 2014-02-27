log     = require 'simplog'
_       = require 'underscore'
path    = require 'path'

attachResponder = (context, conn) ->
  conn.jwrite = (data) =>
    conn.write JSON.stringify(data)
  context.on 'beginquery', (data) ->
    data.message = 'beginquery'
    conn.jwrite data
  context.on 'row', (columns) ->
    columns.message = 'row'
    conn.jwrite columns
  context.on 'beginrowset', () ->
    conn.jwrite message: 'beginrowset'
  context.on 'data', (data) ->
    data.message = 'data'
    conn.jwrite data
  context.on 'error', (err) ->
    # if there's no .message it's gonna need to be a string
    if not err.message
      err.message = err
    conn.jwrite error: err.message.toString()
  context.on 'endquery', (data) ->
    data.message = "endquery"
    conn.jwrite data
  context.on 'completequeryexecution', () ->
    log.debug "close?: #{context.closeOnEnd}"
    if context.closeOnEnd
      conn.close()

module.exports.attachResponder = attachResponder
