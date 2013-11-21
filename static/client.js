/*jshint browser: true, devel: true, indent: 2 */
function Client() {
  "use strict";
  var myId = null, pingCount = 0,  source = new EventSource('/sse');
  window.activeSource = source;

  // sse implementation specific
  // un-named events
  source.addEventListener('message', function (e) { console.log(e); });

  // just something to keep the connection active
  source.addEventListener('ping', function (e) { pingCount++; console.log("ping: " + pingCount); });

  // this assigns us a client id to use to request data from the server (and have it be sent to us)
  source.addEventListener('id_assign',
    function(e) { myId=e.data; console.log("Client ID: " + myId); }
  );
  // /sse implementation specific

  // epiquery events
  source.addEventListener('beginQuery', function (e) { console.log(e); });
  source.addEventListener('endQuery', function (e) { console.log(e); });
  source.addEventListener('row', function (e) { console.log(e);});
  source.addEventListener('beginRowset', function (e) { console.log(e);});
  source.addEventListener('endRowset', function (e) { console.log(e);});
  // /epiquery events

  this.addEventListener = function (name, cb){
    var wrapper = function (e){ console.log(e); cb(JSON.parse(e.data)); };
    source.addEventListener(name, wrapper);
  };

  this.makeRequestHandler = function makeRequest (myId) {
    return function (template) {
      if (typeof(myId) === "undefined"){
        setTimeout(function () { this(template); }, 100);
      } else {
        $.get(template + "?client_id=" + myId);
      }
    };
  };
  this.request = this.makeRequestHandler(myId);
}
