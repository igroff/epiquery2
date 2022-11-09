//Postgres Driver!!!

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

  execute(txt, context) {
    // callback
    this.conn.query(txt, context.templateContext.binds)
    .then(res => {
      console.log(res)
      if (Array.isArray(res))
      {
        res.forEach( rs =>
        {
          this.emit('beginrowset');  
            rs.rows.forEach(r => this.emit('row', r));    
          this.emit('endrowset');
        })
      }
      else
      { 
        this.emit('beginrowset');  
            res.rows.forEach(r => this.emit('row', r));    
        this.emit('endrowset');      
      }
      this.emit('endquery', res);
      
    })
    .catch(e => console.error(e.stack))
    
  }

  connect(cb) {
    log.debug('connect', this.config);
    this.conn = new pg.Client({
      user: this.config.user,
      host: this.config.host,
      password: this.config.password,
      database: this.config.database,
      port: this.config.port,
    });
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
