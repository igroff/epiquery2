#! /usr/bin/env coffee
template  = require '../../src/templates.coffee'
optimist  = require 'optimist'
log       = require 'simplog'

args = optimist.argv

context = JSON.parse(args.context)
templatePath = args.templatePath
template.renderTemplate(
  templatePath,
  context,
  (err, templateContent, renderedTemplate) ->
    process.stdout.write(renderedTemplate)
    process.exit(1)
)
