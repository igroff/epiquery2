function Client(){
  var myId = null;
  var pingCount = 0;
  var source = new EventSource('/sse');
  window.activeSource = source;

  // sse implementation specific
  // un-named events
  source.addEventListener('message', function(e) { console.log(e); })

  // just something to keep the connection active
  source.addEventListener('ping', function(e) { pingCount++; console.log("ping: " + pingCount); });

  // this assigns us a client id to use to request data from the server (and have it be sent to us)
  source.addEventListener('id_assign',
    function(e) { myId= e.data; console.log("Client ID: " + myId); }
  );
  // /sse implementation specific

  // epiquery events
  source.addEventListener('queryBegin', function(e) { console.log('queryBegin'); });
  source.addEventListener('queryComplete', function(e) { console.log('queryComplete'); });
  source.addEventListener('row', function(e) { console.log('row');});
  source.addEventListener('resultSetBegin', function(e) { console.log('resultSetBegin');});
  source.addEventListener('resultSetEnd', function(e) { console.log('resultSetBegin');});
  // /epiquery events

  this.addEventListener = function(name, cb){
    var wrapper = function(e){ console.log(e); cb(JSON.parse(e.data)); }
    source.addEventListener(name, wrapper);
  };

  this.request = function(template) { $.get(template + "?client_id=" + myId); }
}
