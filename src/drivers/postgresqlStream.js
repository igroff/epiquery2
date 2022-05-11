const events = require('events');
const log = require('simplog');
const _ = require('lodash-contrib');
const os = require('os');
const pg = require('pg');
const QueryStream = require('pg-query-stream');
const JSONStream = require('JSONStream');

class PostgresqlDriver  extends events.EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.valid = false;
  }

  execute(query, context) {
    log.debug(query, context.templateContext)
    const stream = this.conn.query(new QueryStream(query, context.templateContext.binds));
    stream.pipe(JSONStream.stringify())

    let rowSetStarted = false;
    stream.on('data', record => {
      if (!rowSetStarted) {
        rowSetStarted = true;
        this.emit('beginrowset');
      }
      this.emit('row', record);
    });
    stream.on('end', query => {
      if (rowSetStarted) {
        this.emit('endrowset');
      }
      this.emit('endquery', query);
    });
    stream.on('error', error => {
      if (rowSetStarted) {
        this.emit('endrowset');
      }
      this.valid = false;
      this.emit('error', error);
    });
  }

  connect(cb) {
    log.debug('connect', this.config);
    this.conn = new pg.Client(this.config);
    this.conn.connect(err => {
      if(err) {
        log.error(`Failed connecting to postgres \n${err}`)
      } else {
        this.valid = true;
        log.debug("Connected to postgres");
      }
      cb(err, this);
    });
  }

  disconnect() {
    this.conn.end();
  }

  validate() {
    return this.valid;
  }
}

module.exports.DriverClass = PostgresqlDriver
