# vim: ft=coffee
clients = require './EpiClient.coffee'

module.exports.EpiClient = clients.EpiClient
module.exports.EpiBufferingClient = clients.EpiBufferingClient
if window?
  window.EpiClient = clients.EpiClient
  window.EpiBufferingClient = clients.EpiBufferingClient
