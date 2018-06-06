/*
  executionMasks:
    a_valid_bitmask: 1
*/
/*
  Generally parameters are declared as follows, with no whitespace preceeding the line
--<sql variable name> <type> = <field name in request>

The following are some examples
*/

--@varcharParam varchar = aVarchar
--@nvarcharParam nvarchar = aNVarchar
--@intParam int = anInt
--@bitParam bit = aBit
--@tinyIntParam tinyint = aTinyInt
--@dateTimeParam datetime = aDateTime

/*
  you can also omit the '= <field name in request>' part  if you are willing to use the same name in the
  request as you use for the parameter. Thus, in the inbound request, if you have a value for
  'myVarcharParam' then it will get used as the value for the following parameter 
*/
--@myVarcharParam varchar


/* You can call this template in various ways, the following examples use curl to do so

curl -s 'http://localhost:8080/simple/mssql/test/template_parameter_examples.sql?aVarchar=jeans&anInt=3&aBit=0&aTinyInt=42&aDateTime=01/01/2018%2001:01:59&aNVarchar=something%20unicode&myVarcharParam=nice'

  or 

curl -s 'http://localhost:8080/simple/mssql/test/template_parameter_examples.sql' -H 'Content-Type: application/json' --data '{"aVarchar":"jeans","anInt":3,"aBit":0,"aTinyInt":42,"aDateTime":"01/01/2018 001:01:59","aNVarchar":"something unicdoe","myVarcharParam":"nice"}'


Keep in mind, with a querystring all of the parameters are ... strings. The only way to get typing, if you expect it, is to pass a JSON object. For example, the following will pass a null for 'anInt'

curl -s 'http://localhost:8080/simple/mssql/test/template_parameter_examples.sql' -H 'Content-Type: application/json' --data '{"aVarchar":"jeans","anInt":null,"aBit":0,"aTinyInt":42,"aDateTime":"01/01/2018 001:01:59","aNVarchar":"something unicdoe","myVarcharParam":"nice"}'

If you want to set the same parameter to null but use the query string, you must _omit_ it.
e.g.
curl -s 'http://localhost:8080/simple/mssql/test/template_parameter_examples.sql?aVarchar=jeans&aBit=0&aTinyInt=42&aDateTime=01/01/2018%2001:01:59&aNVarchar=something%20unicode&myVarcharParam=nice'

If you specify 'null' in the querystring, the database will attempt to coerce the _string_ 'null' into an int which will fail.

e.g.

$ curl -s 'http://localhost:8080/simple/mssql/test/template_parameter_examples.sql?aVarchar=jeans&anInt=null&aBit=0&aTinyInt=42&aDateTime=01/01/2018%2001:01:59&aNVarchar=something%20unicode&myVarcharParam=nice' | jq .
{
  "results": [
    {
      "message": "error",
      "errorDetail": {
        "message": "Validation failed for parameter 'intParam'. Invalid number.",
        "code": "EPARAM"
      },
      "error": "Validation failed for parameter 'intParam'. Invalid number."
    }
  ]
}

*/

select @varcharParam [aVarchar]
select @intParam [anInt]
select @bitParam [aBit]
select @tinyIntParam [aTinyInt]
select @dateTimeParam [aDateTime]
select @nvarcharParam [aNVarchar]
select @myVarcharParam [myVarcharParam]
