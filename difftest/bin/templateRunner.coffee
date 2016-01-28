#! /usr/bin/env coffee
template  = require '../../src/templates.coffee'
optimist  = require 'optimist'
log       = require 'simplog'

args = optimist.argv

context = JSON.parse(args.context)
templatePath = args.templatePath
template.init()
template.renderTemplate(
  templatePath,
  context,
  (err, templateContent, renderedTemplate) ->
    if err
     console.log err
    else
      console.log renderedTemplate
    process.exit(1)
)
