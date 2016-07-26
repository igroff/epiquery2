#! /usr/bin/env node_modules/.bin/coffee

log = require 'simplog'

fs = require 'fs'
# 0x0080 O_SYNC
# 0x0020 O_EXLOCK
# 0x0400 O_TRUNC
# 0x0200 O_CREAT
# 0x0004 O_NONBLOCK
# 0x0002 F_WRITE
flags = 0x0080 | 0x0020 | 0x0400 | 0x0200 | 0x0004 | 0x0002

tryAquireLock = (lockFilePath) ->
  try
    fd = fs.openSync(lockFilePath, flags)
    # this is purely to help in any debugging that may be needed
    fs.writeSync(fd, new Date() + " - " + process.pid)
    log.debug "aquired lock for file #{lockFilePath}"
    return fd
  catch e
    # EAGAIN is raised if it's already locked which means
    # we couldn't aquire the lock
    if e.message?.substring("EAGAIN") < 1
      # if we get an error other than EAGAIN, we have some 
      # unexpected state
      throw e
    log.debug "unable to aquire lock for file #{lockFilePath}"
    return undefined

releaseLock = (lockFileDescriptor) ->
  fs.closeSync(lockFileDescriptor)

module.exports.releaseLock = releaseLock
module.exports.tryAquireLock = tryAquireLock

fd = tryAquireLock('./lock.file')

if not fd
  console.log "couldn't lock the file"
  process.exit(0)

process.on 'SIGINT', () ->
  console.log 'being terminated'
  releaseLock(fd)
  process.exit(0)

die = () ->
  console.log 'timed out'
  process.kill(process.pid, 'SIGINT')
setTimeout(die, 300000)
