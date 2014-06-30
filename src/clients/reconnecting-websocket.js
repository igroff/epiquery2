function MakeWebSocketReconnecting(){
  var OriginalWebSocket = null;
  if ( typeof(WebSocket) === "undefined" ){
    OriginalWebSocket = require("ws");
  } else {
    OriginalWebSocket = WebSocket;
  }
  function ReconnectingWebSocket(url, protocols){
    RECONNECTING = 99;
    ERRORED = 100;
    // WS Events
    this.onopen    = function () {};
    this.onerror   = function () {};
    this.onclose   = function () {};
    this.onmessage = function () {};

    var underlyingWs        = null;
    var reconnectOnClose    = true;
    var reconnectAttempts   = 0;
    var readyState         = -1;

    this.ondatanotsent = function() {};

    Object.defineProperty( this, 'url',
      { get: function(){ return underlyingWs.url; }}
    );
    Object.defineProperty( this, 'readyState',
      { get: function(){ return readyState; }}
    );
    Object.defineProperty( this, 'binaryType',
      { get: function(){ return underlyingWs.binaryType; }}
    );
    Object.defineProperty( this, 'extensions',
      { get: function(){ return underlyingWs.extensions; }}
    );
    Object.defineProperty( this, 'bufferedAmount',
      { get: function(){ return underlyingWs.bufferedAmount; }}
    );

    function reconnect() {
      if ( readyState === OriginalWebSocket.CONNECTING ||
           readyState === RECONNECTING || 
           underlyingWs.readyState === OriginalWebSocket.CONNECTING ){
        return; }
      // exponential backoff on delay, capped at a wait of 1024 ms
      var delay = reconnectAttempts++ > 9 ? 1024 : Math.pow(2, reconnectAttempts);
      readyState = RECONNECTING;
      setTimeout(connect, delay);
    }
    // make it 'public' too
    this.reconnect = reconnect;

    function connect() {
      readyState = OriginalWebSocket.CONNECTING;
      // an attempt to avoid get extraneous events
      if ( underlyingWs !== null ){
        underlyingWs.onerror = null;
        underlyingWs.onmessage = null;
        underlyingWs.onclose = null;
        // we don't need to do anything with onopen because it wouldn't
        // fire again anyway, and shouldn't keep the socket from getting
        // GCd
      }
      underlyingWs = new OriginalWebSocket(url, protocols || []);
      underlyingWs.onopen  = function(evt){
        readyState = OriginalWebSocket.OPEN;
        this.onopen(evt);
        reconnectAttempts = 0; // reset
      }.bind(this); 

      // onclose, unless told to close by having our close() method called
      // we'll ignore the close, and reconnect
      underlyingWs.onclose = function(evt){
        readyState = OriginalWebSocket.CLOSED;
        if (reconnectOnClose){
          reconnect();
        } else {
          this.onclose(evt);
        }
      }.bind(this);

      underlyingWs.onerror = function(evt) {
        readyState = ERRORED;
        this.onerror(evt);
      }.bind(this);

      underlyingWs.onmessage = this.onmessage;
    }


   this.send = function (data){
      // if the socket isn't open, we'll just reconnect and let the
      // caller try again cause we know this raises an uncatchable
      // error
      if (underlyingWs.readyState != OriginalWebSocket.OPEN){
        reconnect();
        this.ondatanotsent(data);
      } else {
        // otherwise we try to send, and if we have a failure
        // we'll go ahead and reconnect, telling our caller
        // all about how we failed via onsendfailed
        try {
          underlyingWs.send(data);
        } catch (error) {
          reconnect();
          this.ondatanotsent(data);
        }
      }
    }.bind(this);

    this.close = function () {
      reconnectOnClose = false;
      underlyingWs.close();
    }.bind(this);

    setTimeout(connect.bind(this), 0);
  }
  // WS Constants the the 'class' Level
  ReconnectingWebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
  ReconnectingWebSocket.OPEN       = OriginalWebSocket.OPEN;
  ReconnectingWebSocket.CLOSING    = OriginalWebSocket.CLOSING;
  ReconnectingWebSocket.CLOSED     = OriginalWebSocket.CLOSED;

  WebSocket = ReconnectingWebSocket; 
  UnMakeWebSocketReconnecting = function(){
    WebSocket = OriginalWebSocket;
    UnMakeWebSocketReconnecting = null;
  };
}

module.exports = MakeWebSocketReconnecting;
