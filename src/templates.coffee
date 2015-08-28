hogan     = require 'hogan.js'
dot       = require 'dot'
async     = require 'async'
log       = require 'simplog'
fs        = require 'fs'
path      = require 'path'
_         = require 'underscore'

# whitespace is important, we don't want to strip it
dot.templateSettings.strip = false

# keep track of our renderers, we're storing them by
# their associated file extension as that is how we'll
# be looking them up
renderers = {}
renderers[".dot"] =  (templateString, context) ->
  templateFn = dot.template templateString
  templateFn context

renderers[".mustache"] =  (templateString, context) ->
  template = hogan.compile templateString
  template.render context

# set our default handler, which does nothing
# but return the templateString it was given
renderers[""] = (templateString) ->
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
  fs.readFile templatePath, {encoding: 'utf8'}, callbackWithData

renderTemplate = (templatePath, templateContent, context, cb) ->
  log.debug "renderingTemplate #{templatePath}"
  renderer = getRendererForTemplate templatePath
  rendered = renderer templateContent.toString(), context
  log.debug "renderd template content:\n%s", rendered
  cb null, [templateContent, rendered]

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
        cb(err)
      else
        results.unshift(err)
        cb.apply cb, results
