EventEmitter      = require('events').EventEmitter
_                 = require 'underscore'
log               = require 'simplog'
AwesomeWebSocket  = require('awesome-websocket').AwesomeWebSocket

guid = ->
  s4 = ->
    return Math.floor((1 + Math.random()) * 0x10000)
               .toString(16)
               .substring(1)

    return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
      s4() + '-' + s4() + s4() + s4()

class EpiClient extends EventEmitter
  constructor: (@url, @writeUrl, @sqlReplicaConnection, @sqlMasterConnection) ->
    @connect()
    @last_write_time = null
    @write_counter = 0
    @write_queryId = null
    @pending_queries = {}

  connect: =>
    # we have a couple possible implementations here, HuntingWebsocket
    # expects an array of urls, so we make that if needed
    @ws = new AwesomeWebSocket(@url)
    @queryId = 0
    @ws.onmessage = @onMessage
    @ws.onclose = @onClose
    @ws.onopen = () =>
      log.debug "Epiclient connection opened"
      @ws.keepAlive(60 * 1000, 'ping');
    @ws.onerror = (err) ->
      log.error "EpiClient socket error: ", err
    @ws.onsend = @onsend

    if @writeUrl
      @ws_w = new AwesomeWebSocket(@writeUrl)
      @ws_w.onmessage = @onMessage
      @ws_w.onclose = @onClose
      @ws_w.onopen = () =>
        log.debug "Epiclient connection opened (write)"
        @ws_w.keepAlive(60 * 1000, 'ping');
      @ws_w.onerror = (err) ->
        log.error "EpiClient socket error (write): ", err
      @ws_w.onsend = @onsend

  query: (connectionName, template, data, queryId=null, force_write=false) =>
    req =
      templateName: template
      connectionName: connectionName
      data: data

    req.queryId = queryId || guid()
    req.closeOnEnd = data.closeOnEnd if data

    if force_write and !@last_write_time
      @last_write_time = new Date(2050, 0)
      req.is_write = true

    @pending_queries[req.queryId] = JSON.parse(JSON.stringify(req)) # crappy copy...

    #switched to write. use the socket to Austin instead unless checking replication time
    if @last_write_time and @ws_w and queryId != 'replica_replication_time'
      # if someone has asked us to close on end, we want our fancy
      # underlying reconnectint sockets to not reconnect
      @ws_w.forceClose = req.closeOnEnd
      
      log.debug "executing query: #{template} data:#{JSON.stringify(data)}"
      req.connectionName = @sqlMasterConnection
      @ws_w.send JSON.stringify(req)
    else
      # if someone has asked us to close on end, we want our fancy
      # underlying reconnectint sockets to not reconnect
      @ws.forceClose = req.closeOnEnd
      
      log.debug "executing query: #{template} data:#{JSON.stringify(data)}"
      @ws.send @pending_queries[req.queryId]

  onMessage: (message) =>
    # if the browser has wrapped this for use, we'll be interested in its
    # 'data' element
    if message.data == 'pong'
      return
    message = message.data if message.type? and message.type = 'message'
    message = JSON.parse(message) if typeof message is 'string'
    handler = @['on' + message.message]
    if handler
      handler(message)
  
  onClose: () =>
    @emit 'close'

  onrow: (msg) =>
    if msg.queryId == 'replica_replication_time'
      log.info 'replica is timestamped at', msg.columns[0].value
      replica_timestamp = new Date(msg.columns[0].value)
      unlabeled_pending_queries = _.filter @pending_queries, (query) -> query.is_write != undefined and query.is_read != undefined
      if replica_timestamp > @last_write_time and not unlabeled_pending_queries.length > 0
        log.info 'replica has recovered'
        @last_write_time = null
        @write_counter = 0
      else
        setTimeout =>
          @query(@sqlReplicaConnection, 'get_replication_time.mustache', null, 'replica_replication_time')
        , 1000
    else if msg.queryId == @write_queryId
      log.info 'write is timestamped at', msg.columns[0].value
      @last_write_time = new Date(msg.columns[0].value)
      if @write_counter == 1
        @query(@sqlReplicaConnection, 'get_replication_time.mustache', null, 'replica_replication_time')
    else
      @emit 'row', msg
  ondata: (msg) => @emit 'data', msg
  onbeginquery: (msg) =>
    if @pending_queries[msg.queryId] and not @pending_queries[msg.queryId].is_write
      @pending_queries[msg.queryId].is_read = true
    @emit 'beginquery', msg
  onendquery: (msg) =>
    if @pending_queries[msg.queryId]
      if @pending_queries[msg.queryId].is_write
        @write_counter += 1
        @write_queryId = 'write_replication_time' + @write_counter
        @query(@sqlMasterConnection, 'get_replication_time.mustache', null, @write_queryId)
      delete @pending_queries[msg.queryId]
    @emit 'endquery', msg
  onerror: (msg) =>
    if msg.error == 'replicawrite'
      log.info 'eating error...nom nom'
      @last_write_time = new Date(2050, 0)
      query_data = @pending_queries[msg.queryId]
      query_data.is_write = true
      log.info 'replica write.  switching to master'
      @emit 'replicawrite', msg
      @query(@sqlMasterConnection, query_data.templateName, query_data.data, msg.queryId)
    else
      @emit 'error', msg
  onbeginrowset: (msg) => @emit 'beginrowset', msg
  onendrowset: (msg) => @emit 'endrowset', msg
  onsend: (msg) => @emit 'send', msg
  onreplicamasterwrite: (msg) =>
    query_data = @pending_queries[msg.queryId]
    query_data.is_write = true
    @pending_queries[msg.queryId] = query_data
    if @write_counter == 0
      log.info "Master write detected.  Initial write, setting timestamp on endquery."
    else
      log.info "Master write detected. Increasing timestamp on endquery."

class EpiBufferingClient extends EpiClient
  constructor: (@url, @writeUrl, @sqlReplicaConnection, @sqlMasterConnection) ->
    super(@url, @writeUrl, @sqlReplicaConnection, @sqlMasterConnection)
    @results = {}

  onrow: (msg) =>
    if msg.queryId == 'replica_replication_time'
      log.info 'replica is timestamped at', msg.columns[0].value
      replica_timestamp = new Date(msg.columns[0].value)
      unlabeled_pending_queries = _.filter @pending_queries, (query) -> query.is_write != undefined and query.is_read != undefined
      if replica_timestamp > @last_write_time and not unlabeled_pending_queries.length > 0
        log.info 'replica has recovered'
        @last_write_time = null
        @write_counter = 0
      else
        setTimeout =>
          @query(@sqlReplicaConnection, 'get_replication_time.mustache', null, 'replica_replication_time')
        , 1000
    else if msg.queryId == @write_queryId
      log.info 'write is timestamped at', msg.columns[0].value
      @last_write_time = new Date(msg.columns[0].value)
      if @write_counter == 1
        @query(@sqlReplicaConnection, 'get_replication_time.mustache', null, 'replica_replication_time')
    else
      @results[msg.queryId]?.currentResultSet?.push(msg.columns)
  
  onbeginrowset: (msg) =>
    newResultSet = []
    @results[msg.queryId] ||= resultSets: []
    @results[msg.queryId].currentResultSet = newResultSet
    @results[msg.queryId].resultSets.push newResultSet

module.exports.EpiClient = EpiClient
module.exports.EpiBufferingClient = EpiBufferingClient
