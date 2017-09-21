hogan     = require 'hogan.js'
dot       = require 'dot'
log       = require 'simplog'
fs        = require 'fs'
path      = require 'path'
_         = require 'lodash'
config    = require './config.coffee'
util      = require 'util'
yaml      = require 'js-yaml'

getRelativeTemplatePath = (templatePath) ->
  # as per the MDN
  #   If either argument is greater than stringName.length,
  #   it is treated as if it were stringName.length.
  templatePath.substring(config.templateDirectory.length + 1, 9999)

# whitespace is important, we don't want to strip it
dot.templateSettings.strip = false

# precompiled templates loaded by hogan during initilization
hoganTemplates = null

# keep track of our renderers, we're storing them by
# their associated file extension as that is how we'll
# be looking them up
renderers = {}

# here we will put any (mustache) lambda functions we fin
mustacheLambdas = null

renderers[".dot"] = (templatePath, context, cb) ->
  log.debug "rendering #{templatePath} with dot renderer"
  fs.readFile templatePath, {encoding: 'utf8'}, (err, templateString) ->
    if err
      cb(err)
    else
      renderedTemplate = dot.template(templateString)(context)
      [templateConfig, renderedTemplateWithoutFrontMatter] = parseFrontMatter(renderedTemplate)
      cb(null, templateString, renderedTemplateWithoutFrontMatter, templateConfig)

renderers[".mustache"] = (templatePath, context, cb) ->
  log.debug "rendering #{templatePath} with mustache renderer"
  relativeTemplatePath = getRelativeTemplatePath(templatePath)
  template = hoganTemplates[relativeTemplatePath]
  context = _.extend(context, mustacheLambdas)
  if template
    renderedTemplate = template.render(context, hoganTemplates)
    # yes we parse out the config ( via frontmatter ) every time, this is because it's theoretically
    # desirable to template out your frontmatter as well. If you think this overhead is too much, you're probably
    # wrong, and if you've proven you're not we can do something about it then
    [templateConfig, renderedTemplateWithoutFrontMatter] = parseFrontMatter(renderedTemplate)
    cb(null, template.text, renderedTemplateWithoutFrontMatter, templateConfig)
  else
    cb(new Error("could not find template: #{relativeTemplatePath}"))

# set our default handler, which does nothing
# but return the the contents of the template it was provided
renderers[""] = (templatePath, _, cb) ->
  log.debug "rendering #{templatePath} with generic renderer"
  fs.readFile templatePath, {encoding: 'utf8'}, (err, templateString) ->
    if err
      cb(err)
    else
      [templateConfig, templateWithoutFrontMatter] = parseFrontMatter(templateString)
      cb(null, templateString, templateWithoutFrontMatter, templateConfig)

# <"as is" renderers>
# first .sproc, you know for fun
renderers[".sproc"] = renderers[""]
renderers[".sql"] = renderers[""]
# </"as is" renderers>

getRendererForTemplate = (templatePath) ->
  renderer = renderers[path.extname templatePath]
  # have a 'default' renderer for any unrecognized extensions
  if renderer
    return renderer
  else
    return renderers[""]

parseFrontMatter = (templateString) ->
  if templateString?.indexOf("/*\n") is 0
    try
      endOfFrontMatter = templateString.indexOf("*/\n", 2)
      frontMatter = templateString.substring(2, endOfFrontMatter)
      log.debug "parsing frontmatter\n#{frontMatter}"

      frontMatterParsed = yaml.load(frontMatter + "\n", 'utf8')
      log.debug "parsed frontmatter: %j", frontMatterParsed

      # strip off the front matter, running past the leng of string with the end pos
      # simply results in the whole string
      templateStringWithoutFrontMatter = templateString.substring(endOfFrontMatter + 2)
      # just making sure we're not leading off with a dangling newline from the frontmatter
      if templateStringWithoutFrontMatter.substring(0,1) is "\n"
        templateStringWithoutFrontMatter = templateStringWithoutFrontMatter.substring(1)
      return [frontMatterParsed, templateStringWithoutFrontMatter]
    catch error
      log.debug "Could not parse front matter: %s", error

  return [undefined, templateString]


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
      fileList.push(fullPath) if path.extname(name) is ".mustache"
  fileList

initialize = () ->
  # allows for any initialization a template provider needs to do
  # in this case we'll be compiling all the mustache templates so that
  # we can use partials. Any state created by this process will be
  # swapped with existing state when initialize is complete, this
  # will allow initialize to be run while epiquery is active
  ############################################
  # first we load our templates
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
  # swap in the newly loaded templates
  hoganTemplates = templates
  ############################################
  # then we get our mustacheLambdas
  lambdaPath = path.join(config.templateDirectory, 'mustache_lambdas.js')
  if fs.existsSync(lambdaPath)
    # first we make sure to clear the cache, so we can assure we
    # load the latest
    delete require.cache['./lambdas.coffee']
    # and we load it
    mustacheLambdas = require './lambdas.coffee'
    # then we tell the module to load the lambdas, which brings them in as
    # module members
    mustacheLambdas.loadLambdas(lambdaPath)
    log.debug "lambdas: #{util.inspect(mustacheLambdas)}"

module.exports.init = initialize
module.exports.renderTemplate = (templatePath, context, cb) ->
  renderer = getRendererForTemplate(templatePath)
  templateCallback = (err, templateUnrendered, templateRendered, templateConfig) ->
    cb(err, templateUnrendered, templateRendered, templateConfig)
  renderer(templatePath, context, templateCallback)
