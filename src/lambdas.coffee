fs = require 'fs'
log = require 'simplog'

# The whole purpose of this module is to serve as the module into which our lambdas
# will be loaded, so our single method evals the lambda file
module.exports.loadLambdas = (fromThisFilePath) ->
  log.info "loading lambdas from #{fromThisFilePath}"
  eval(fs.readFileSync(fromThisFilePath).toString())
