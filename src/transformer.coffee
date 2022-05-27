fs     = require 'fs'
config = require './config.coffee'
log    = require 'simplog'
path   = require 'path'
vm     = require 'vm'
coffee = require 'coffee-script'

loadedTransforms = {}

# given the name of a response transformation (file name), load it from the
# proper location
getRequestedTransform = (transformName, cb) ->
  if not transformName
    log.error "no transformName provided, unable to load transform"
    cb new Error("no transformName provided, unable to load transform")
    return false
  log.debug "loading requested response transform: #{transformName}"
  try
    # calculate the path for the transform location, so that we can
    # clear the cache, templates are loaded on each execution so the expectation
    # will be the same for the transforms
    transformPath = path.join(config.responseTransformDirectory, transformName)
    log.debug "full path to transform: #{transformPath}"
    transformFunction = loadedTransforms[transformPath]
    if transformFunction
      log.debug "using cached transform for #{transformPath}"
      cb(null, transformFunction)
      return true
    else
      log.debug "loading transformation from #{transformPath}"
      fs.readFile transformPath, (err, data) ->
        return cb(err) if err
        scriptContext = vm.createContext( module: {} , require: require)
        try
          # compile it, if we're given coffeescript
          if ".coffee" is path.extname(transformPath)
            log.debug "response tranform provided appears to be coffee script"
            log.debug require('util').inspect(coffee.compile)
            data = coffee.compile(data.toString('utf8'), {header:false, bare: true})
          transformFunction = vm.runInContext(data, scriptContext)
          # cache up our transform for later use
          loadedTransforms[transformPath] = transformFunction
        catch e
          log.error "error during load of response transform #{transformName}\n#{e.stack}"
          cb(new Error("error during load of response transform #{transformName}"))
          return false
        cb(null, transformFunction)
        return true
  catch e
    log.error "error loading transform: #{transformName}\n #{e}"
    cb(new Error("failed to load transform #{transformName}"))
    return false

clearCache = () ->
  log.info "clearing response transformation cache"
  removeCacheEntry = (transformPath) ->
    log.debug "removing transformation #{transformPath} from cache"
    delete(require.cache[transformPath])
  removeCacheEntry(transformPath) for own transformPath, _ of loadedTransforms
  loadedTransforms = {}

initialize = () ->
  clearCache()

module.exports.getRequestedTransform = getRequestedTransform
module.exports.init = initialize
