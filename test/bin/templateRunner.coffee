#! /usr/bin/env coffee
template  = require '../../src/templates.coffee'
optimist  = require 'optimist'
log       = require 'simplog'

args = optimist.argv

template.renderTemplate(
  args.templatePath,
  JSON.parse(args.context),
  (err, templateData) -> process.stdout.write(templateData.renderedTemplate); process.exit(1)
)
