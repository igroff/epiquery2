#! /usr/bin/env coffee
template  = require '../../src/templates.coffee'
optimist  = require 'optimist'
log       = require 'simplog'

args = optimist.argv

template.renderTemplate(
  args.templatePath,
  JSON.parse(args.context),
  (err, templateContent, renderedTemplate) ->
    process.stdout.write(renderedTemplate)
    process.exit(1)
)
