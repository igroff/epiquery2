#! /usr/bin/env ./node_modules/.bin/coffee

Browser     = require 'zombie'
assert      =  require 'assert'

checkForContent = (browser) ->
  data = browser.innerHtml "#data"
  console.log data
  data isnt ""

Browser.visit "http://localhost:8080/static/test.html", (err, browser) ->
  console.log "starting stuff"
  assert.equal browser.statusCode, 200, "browser returned non 200 status"
  browser.fill "#templateName", "/file/test/my_manifest2"
  browser.pressButton "#executeQuery", ()->
    browser.wait checkForContent, () ->
      browser.close()
      process.exit()
