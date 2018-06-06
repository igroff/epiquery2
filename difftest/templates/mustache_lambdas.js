var _      = require('lodash');
var moment = require('moment');

var sqlString = function(){
  return function(value) {
    return value.replace(/(\r\n|\n)/g, '\\n');
  };
};



var sqlDate = function(isUtc) {
  return function(){
    return function(value) {
      try {
        if (typeof value === 'string') {
          value = new Date(value);   
        }

        if (isUtc) {
          return moment(value).utc().format('YYYY-MM-DDTHH:mm:ss') + 'Z';
        }
        else {
          return moment(value).format('YYYY-MM-DDTHH:mm:ss');
        }

      } catch(err) {
        return undefined;
      }
    };
  };
};

module.exports.sql_string = sqlString;
module.exports.sql_date = sqlDate(false)();
module.exports.sql_date_utc = sqlDate(true);
// for backwards compatibility
module.exports.sql_str = sqlString;
module.exports.sql_dte = sqlDate(false);
module.exports.sql_dte_utc = sqlDate(true);
// just for testing
module.exports.log_it = function() {
  return function(text, render) {
    console.log("someone wanted me to log this for their mom: " + text); 
    return text;
  }
};
module.exports.quote_strings = function(){
  return function(text, render){
    var number = Number.parseFloat(text);
    if (!isNaN(number)){
      return number;
    } else {
      return '"' + text + '"';
    }
  };
};
