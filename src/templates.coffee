hogan     = require 'hogan.js'
dot       = require 'dot'
async     = require 'async'
# regex to replace MS special charactes, these are characters that are known to
# cause issues in storage and retrieval so we're going to switch 'em wherever
# we find 'em
special_characters = {
  "8220": {"regex": new RegExp(String.fromCharCode(8220), "gi"), "replace": '"'} # �~@~\
  ,"8221": {"regex": new RegExp(String.fromCharCode(8221), "gi"), "replace": '"'} # �~@~]
  ,"8216": {"regex":  new RegExp(String.fromCharCode(8216), "gi"), "replace": "'"} # �~@~X
  ,"8217": {"regex": new RegExp(String.fromCharCode(8217), "gi"), "replace": "'"} # �~@~Y
  ,"8211": {"regex": new RegExp(String.fromCharCode(8211), "gi"), "replace": "-"} # �~@~S
  ,"8212": {"regex": new RegExp(String.fromCharCode(8212), "gi"), "replace": "--"} # �~@~T
  ,"189": {"regex": new RegExp(String.fromCharCode(189), "gi"), "replace": "1/2"} # ½
  ,"188": {"regex": new RegExp(String.fromCharCode(188), "gi"), "replace": "1/4"} # ¼
  ,"190": {"regex": new RegExp(String.fromCharCode(190), "gi"), "replace": "3/4"} # ¾
  ,"169": {"regex": new RegExp(String.fromCharCode(169), "gi"), "replace": "(C)"} # ©
  ,"174": {"regex": new RegExp(String.fromCharCode(174), "gi"), "replace": "(R)"} # ®
  ,"8230": {"regex": new RegExp(String.fromCharCode(8230), "gi"), "replace": "..."} # �~@�
}

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

# this is purely to facilitate testing
renderers[".error"] = () ->
  pants_are cool
  throw "pants"

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
  loadTemplate = (templatePath, cb) ->
    callbackWithData = (error, rawTemplate) ->
      cb error, templatePath, rawTemplate, context
    fs.readFile templatePath, {encoding: 'utf8'}, callbackWithData

renderTemplate = (templatePath, templateContent, context, cb) ->
  renderer = getRendererForTemplate template_name
  rendered = renderer template.toString(), template_context
  cb null, {rawTemplate: template, renderedTemplate: renderedTemplate}

module.exports.renderTemplate = (templatePath, context, cb) ->
 stepsToRender = [
    (cb) -> cb templatePath, context,
    templateLoader,
    renderTemplate
  ]
  async.waterfall stepsToRender, cb
