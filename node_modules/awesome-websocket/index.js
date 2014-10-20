var clients = {
  AwesomeWebSocket: require("./src/awesome-websocket.litcoffee")
  ,ReconnectingWebSocket: require("./src/reconnecting-websocket.litcoffee")
};

// avoid overwriting of something that may be there just trying to be nice...
window.ReconnectingWebSocket = window.ReconnectingWebSocket || clients.ReconnectingWebSocket;
window.AwesomeWebSocket = window.AwesomeWebSocket || clients.AwesomeWebSocket;

module.exports.AwesomeWebSocket = clients.AwesomeWebSocket
module.exports.ReconnectingWebSocket = clients.ReconnectingWebSocket
