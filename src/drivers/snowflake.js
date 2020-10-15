const EventEmitter = require('events');
const snowflake    = require('snowflake-sdk');
const log          = require('simplog');

// So this driver to work with snowflake, and there's nothing particularly 
// outstanding about it with the exception of the parameter binding.
// 
// Due to the way in which param binding works in the snowflake-sdk it is possible
// to write a parameterized template using numbered parameter placeholders and
// pass in the parameters for that template as an array of values orderd appropriately
// for the parameter numbers used
//
// A sample of a parameterized template would be
//
//   select * from WARS.BI.D_CLIENT limit :1
// 
// To get that parameter passed in via the request the caller would have to provide
// a JSON object with a 'binds' property as an array in the request, like:
//
// curl localhost:8080/simple/snowflake/test/basic.snowflake-param -H 'Content-Type: application/json' --data '{"binds": [1]}'
//
// There is no significance to the template file extension at this time

class SnowflakeDriver extends EventEmitter {

  constructor(config) {
    super();
    this.config = config;
    this.valid = false;
  }

  execute(query, context) {
    log.debug(`executing Snowflake query ${query}`);
    const stream = this.conn.execute({sqlText: query, binds: context.templateContext.binds}).streamRows();
    stream.on('data', record => {
      this.emit('row', record);
    });
    stream.on('end', query => {
      this.emit('endquery', query);
    });
    stream.on('error', error => {
      this.valid = false;
      this.emit('error', error);
    });
  }

  connect(cb) {
    log.debug("connecting snowflake account: ", this.config.account);
    snowflake.configure({insecureConnect: true});
    this.conn = snowflake.createConnection(this.config);
    this.conn.connect((err, conn) => {
      if (err) {
        log.error(`Failed connecting to snowflake\n${err}`);
      } else {
        this.valid = true;
        log.debug("Connected to snowflake");
      }
      cb(err, this);
    });
  }

  disconnect() {
    this.conn.destroy((err, conn) => {
      log.debug("connection to snowflake account %s closed", this.config.account);
      if (err) {
        log.error(`Error disconnecting Snowflake account ${this.config.account}\n${err}`);
      }
    });
  }
      
  validate() {
    return this.valid;
  }
}

module.exports.DriverClass = SnowflakeDriver;
