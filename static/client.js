function Client(){
  var myId = null;
  var pingCount = 0;
  var source = new EventSource('/sse');
  source.addEventListener('message', function(e) { console.log(e); })
  source.addEventListener('ping', function(e) { pingCount++; console.log("ping: " + pingCount); });
  source.addEventListener('pants', function(e) { console.log(e); })
  source.addEventListener('id_assign', function(e) { myId= e.data; console.log("Client ID: " + myId); });
  this.addEventListener = function(name, cb){
    source.addEventListener(name, cb);
  };

  this.request = function(template) { $.get(template + "?client_id=" + myId); }
}
