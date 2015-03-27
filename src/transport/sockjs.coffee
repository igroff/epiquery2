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
  context.on 'beginrowset', (data) ->
    data.message = 'beginrowset'
    conn.jwrite data
  context.on 'replicamasterwrite', (queryId) ->
    response =
      message: 'replicamasterwrite'
      queryId: queryId
    conn.jwrite response
  context.on 'endrowset', (data) ->
    data.message = 'endrowset'
    conn.jwrite data
  context.on 'data', (data) ->
    data.message = 'data'
    conn.jwrite data
  context.on 'error', (err, msg) ->
    # if there's no .message it's gonna need to be a string
    response =
      queryId: msg?.queryId || context?.queryId
      error: err.message || err
      message: 'error'
    log.error "[#{context.queryId}] sockjs transport error: #{response.error}"
    conn.jwrite response
  context.on 'endquery', (data) ->
    data.message = "endquery"
    conn.jwrite data
  context.on 'completequeryexecution', () ->
    log.debug "close?: #{context.closeOnEnd}"
    if context.closeOnEnd
      conn.close()

module.exports.attachResponder = attachResponder
