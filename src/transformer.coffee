fs     = require 'fs'
config = require './config.coffee'
log    = require 'simplog'
path   = require 'path'

# given the name of a response transformation (file name), load it from the 
# proper location
getRequestedTransform = (transformName, cb) ->
  # if the requestor asks for a tranform, we'll go ahead and load it
  if transformName
    log.debug "loading requested response transform: #{transformName}"
    try
      # calculate the path for the transform location, so that we can 
      # clear the cache, templates are loaded on each execution so the expectation
      # will be the same for the transforms
      transformPath = path.join(config.responseTransformDirectory, transformName)
      log.debug "full path to transform: #{transformPath}"
      delete(require.cache[transformPath])
      return cb(null, require(transformPath))
    catch e
      log.error "error loading transform: #{transformName}"
      log.error e.message
      return cb(new Error("failed to load transform #{transformName}"))

module.exports.getRequestedTransform = getRequestedTransform
