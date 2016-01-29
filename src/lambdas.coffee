fs = require 'fs'
log = require 'simplog'

module.exports.loadLambdas = (fromThisFilePath) ->
  log.info "loading lambdas from #{fromThisFilePath}"
  eval(fs.readFileSync(fromThisFilePath).toString())
