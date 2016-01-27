hogan     = require 'hogan.js'
dot       = require 'dot'
async     = require 'async'
log       = require 'simplog'
fs        = require 'fs'
path      = require 'path'
_         = require 'underscore'
config    = require './config.coffee'

getRelativeTemplatePath = (templatePath) ->
  templatePath.substring(config.templateDirectory.length + 1, 9999)

# whitespace is important, we don't want to strip it
dot.templateSettings.strip = false

# precompiled templates loaded by hogan during initilization
hoganTemplates = []

# keep track of our renderers, we're storing them by
# their associated file extension as that is how we'll
# be looking them up
renderers = {}
renderers[".dot"] =  (templatePath, templateString, context) ->
  templateFn = dot.template templateString
  templateFn context

renderers[".mustache"] =  (templatePath, templateString, context) ->
  relativeTemplatePath = getRelativeTemplatePath(templatePath)
  log.debug "looking for template #{relativeTemplatePath}"
  template = hoganTemplates[relativeTemplatePath]
  log.debug "using hogan template #{relativeTemplatePath}"
  template.render context, hoganTemplates

# set our default handler, which does nothing
# but return the templateString it was given
renderers[""] = (_, templateString) ->
  templateString

getRendererForTemplate = (templatePath) ->
  renderer = renderers[path.extname templatePath]
  # hava 'default' renderer for any unrecognized extensions
  if renderer
    return renderer
  else
    return renderers[""]


templateLoader = (templatePath, context, cb) ->
  log.debug "loading template %s", templatePath
  callbackWithData = (error, rawTemplate) ->
    cb error, templatePath, rawTemplate, context
  # in the case of mustache templates, all our loading of templates is done
  # during a call to initialize, so we really don't want to do anything here
  if path.extname(templatePath) is ".mustache"
    log.debug "looks like we have a mustache template, we won't load it as it has been precompiled"
    cb null, templatePath, null, context
  else
    fs.readFile templatePath, {encoding: 'utf8'}, callbackWithData

renderTemplate = (templatePath, templateContent, context, cb) ->
  log.debug "renderingTemplate #{templatePath}"
  renderer = getRendererForTemplate templatePath
  templateContent = templateContent.toString() if templateContent isnt null
  rendered = renderer templatePath, templateContent, context
  log.debug "renderd template content:\n%s", rendered
  cb null, [templateContent, rendered]

getMustacheFiles = (templateDirectory, fileList=[]) ->
  names = fs.readdirSync(templateDirectory)
  _.each names, (name) ->
    fullPath = path.join(templateDirectory, name)
    stat = fs.statSync(fullPath)
    if stat.isDirectory()
      # never descend into a directory named git
      return if name is ".git"
      getMustacheFiles(fullPath, fileList)
    else
      fileList.push(fs.realpathSync(fullPath)) if path.extname(name) is ".mustache"
  fileList

initialize = () ->
  # allows for any initialization a template provider needs to do
  # in this case we'll be compiling all the mustache templates so that
  # we can use partials. Any state created by this process will be 
  # swapped with existing state when initialize is complete, this 
  # will allow initialize to be run while epiquery is active
  #
  # we will:
  # 1. walk the template directory building a list of files
  # 2. filter the list removing anything that isn't a template, or is not mustache
  # 3. render the remaining paths as templates, logging any errors we 
  #    encounter.
  # 4. swap the newly created list of rendered templates with our
  #    module level hoganTemplates variable
  #
  log.debug("precompiling mustache templates from #{config.templateDirectory}")
  mustachePaths = getMustacheFiles(config.templateDirectory)
  log.debug("precompiled #{mustachePaths.length} mustache templates")
  templates = {}
  # compile all of the templates
  _.each mustachePaths, (mustachePath) ->
      try
        # we're going to use a key relative to the root of our template directory, as it
        # is epxected that the templates will be stored in their own repository and used
        # anywhere, and we'll remove the leading / so it's clear that the path is relative
        templates[getRelativeTemplatePath(mustachePath)] = hogan.compile(fs.readFileSync(mustachePath).toString())
      catch e
        log.error "error precompiling template #{mustachePath}, it will be skipped"
        log.error e
  log.debug _.keys(templates)
  # swap in the newly loaded templates
  hoganTemplates = templates
    


module.exports.renderTemplate = (templatePath, context, cb) ->
  stepsToRender = [
    # this step is only to get our parameters that our real workers expect
    # into the callback 'stream'
    (bootstrapCallback) -> bootstrapCallback(null, templatePath, context),
    templateLoader,
    renderTemplate
  ]
  async.waterfall stepsToRender,
    (err, results) ->
      if err
        log.error "error during template render"
        cb(err)
      else
        results.unshift(err)
        cb.apply cb, results
module.exports.init = initialize
