## Websockets suck. I use 'normal' HTTP

 Table of Contents

 * [Development](#development)

Ok, so websockets can kind of suck.  And lots of people are more comfortable
with the request/response behavior of 'standard' HTTP as opposed to the asynch
event based nature of websockets. To that end, we offer multiple transport
formats for HTTP.

First a little about HTTP requests to epiquery.

The general format is as follows:

        http://epiquery.server.com/[optional format]/<required connection name>/template_path

Epiquery 2 supports multiple named connections, so the _connection name_ portion of
the url is required, as is the template path.  As an option you may provide a
format specifier, currently epiquery 2 supports two optional formats `simple` or `epiquery1`.

So the following would execute the template */test/servername* against the connection named *pants*:

        http://epiquery.server.com/pants/test/servername


## Development


You need to run the server in the background or another tab before running the tests.

#### Environment Setup

* The server needs the time zone (`TZ`) set. This can be accomplished with the following:

    TZ=UTC make start

* If the `DEBUG` variable is set in the make test environment, it will break the tests. To remedy
  this, use the following:

    DEBUG= make test

#### Running Tests

If you want to run the tests locally, you will need to symlink the test config to your ~/.epiquery2 directory.

Example:
```
ln -s {YOUR_PATH_TO_REPO}/epiquery2/difftest/etc/epi_test_config ~/.epiquery2/config
```

ALSO... Add the following to your `/etc/hosts` file:

```
127.0.0.1 mssql
127.0.0.1 sfdc
127.0.0.1 mysql
```

#### HTTP Response Format Examples

In our examples we'll assume a epiquery instance running locally with a connection named
*pants* to a local MSSQL instance named *PANTSDB*.

##### Standard

First the 'standard' HTTP format, this format mirrors the websocket api and thus is fairly
chatty showing all the events as elements in an array.  You're probably not interested, so you'll have to look way down below to see more detail about those events.


        $ curl http://localhost:8080/pants/test/servername
        {
          "events":[
          {"queryId":"23303_0","message":"beginquery"},
          {"queryId":"23303_0","message":"beginrowset"},
          {"queryId":"23303_0","columns":[{"value":"PANTSDB","name":""}],"message":"row"},
          {"queryId":"23303_0","message":"endrowset"},
          {"queryId":"23303_0","message":"endquery"}
          ]
        }

##### simple

Next a slightly less obnoxious response format called `simple`.

        $ curl http://localhost:8080/simple/pants/test/servername -s | jq .
        {
          "results": [
            [
              {
                "undefined": "PANTSDB"
              }
            ]
          ]
        }

I'm piping the response to [jq](https://stedolan.github.io/jq/) in the example, simply to make format it for display.

The above format example ( the `simple` format ) returns an array of arrays of objects where the key is the column name ( in the above example the column name is empty thus the string 'undefined' ) and the value is the column data.

The `simple` response format will return a single array for each _result set_ in the query, and an object with properties matching the column names  for each row output by the query. The array of result sets will be assigned to the property 'results' of the response object. Below is an example of a result set with two rows having columns *id* and *name*.

        $ curl http://localhost:8080/simple/pants/test/multiple_rows -s | jq .
        {
          "results": [
            [
              {
                "id": 1,
                "name": "jeans"
              },
              {
                "id": 2,
                "name": "slacks"
              }
            ]
          ]
        }

##### epiquery1

The final format is *epiquery1* and is intended to be identical to the response format used in epiquery 1.  Generally it's the same format as simple without the enclosing object, which is to say it retuns just the array named *results* from the simple format.

        $ curl http://localhost:8080/epiquery1/pants/test/servername -s | jq .
        [
          {
            "undefined": "PANTSDB"
          }
        ]


        $ curl http://localhost:8080/epiquery1/pants/test/multiple_rows -s | jq .
        [
          {
            "id": 1,
            "name": "jeans"
          },
          {
            "id": 2,
            "name": "slacks"
          }
        ]

##### csv

There is an response format that returns data formatted using CSV. This format returns each individual recordset in the response in CSV format separated by a blank line.  A header line is always included, and all string values (including headers) are quoted. Below is a sample of a response containing four result sets having varying data.

Things to note are that you'll want to call a connection using the mssql driver and _not_ the mssql_o driver, as the mssql_o driver will lose identically named columns, thus you will actually not get all the data as you do in that last document if you chose a connection using the mssql_o driver.

````
"Number","SomeValue","AnotherValue","ANumberColumn"
1,"some value","anothe value",3
2,"some value","anothe value",3
3,"some value","anothe value",3
4,"some value","anothe value",3
5,"some value","anothe value",3
6,"some value","anothe value",3
7,"some value","anothe value",3
8,"some value","anothe value",3
9,"some value","anothe value",3
10,"some value","anothe value",3

"Number","SomeValue2","AnotherValue2","ANumberColumn2"
1,"some value","anothe value",3
2,"some value","anothe value",3
3,"some value","anothe value",3
4,"some value","anothe value",3
5,"some value","anothe value",3
6,"some value","anothe value",3
7,"some value","anothe value",3
8,"some value","anothe value",3
9,"some value","anothe value",3
10,"some value","anothe value",3

"id","value","value2"
1,"no nulls","on this line"
2,,"this line has a null"
3,"","this line has an empty string"
,"this one has","a null id"
4,"this one has a null final column",

"id","value","value"
1,"no nulls","on this line"
2,,"this line has a null"
3,"","this line has an empty string"
,"this one has","a null id"
4,"this one has a null final column",
````

##### Gotchas

It's worth noting that only the *standard and csv* formats support multiple columns having the same name. With the simple and epiquery1 formats the last column encountered with a given name will overwrite any previous column data. For example, given the template */test/same_column_name* containing:

        select 'one' [col1], 'two' [col1]

You'll get the following responses:

        $ curl http://localhost:8080/simple/pants/test/same_column_name -s | jq .
        {
          "results": [
            [
              {
                "col1": "two"
              }
            ]
          ]
        }

        $ curl http://localhost:8080/epiquery1/pants/test/same_column_name -s | jq .
        [
          [
            {
              "col1": "two"
            }
          ]
        ]

Whereas standard will provide:

        $ curl http://localhost:8080/glglive/test/same_column_name -s
        {
          "events":[
          {"queryId":"23752_3","message":"beginquery"},
          {"queryId":"23752_3","message":"beginrowset"},
          {"queryId":"23752_3","columns":[{"value":"one","name":"col1"},{"value":"two","name":"col1"}],"message":"row"},
          {"queryId":"23752_3","message":"endrowset"},
          {"queryId":"23752_3","message":"endquery"}
          ]
        }

Notice the inclusion of both columns named *col1* only in the standard response.


## Websockets: I don't care, how do I use it.

Epiquery2 provides a client you can use to connect which simplifies your
interaction with epiquery2 as well as providing reconnection and other
valuable features.

There are currently three versions of the client, the original ( without `_v*` )
and `_v2` should not be used by any new applications and are only there for
legacy apps so they don't have to unwillingly take new functionality.

##### Simple Client Example

      <script src="http://some.epiquery.server/static/js/epiclient_v3.js"></script>
      <script type="text/javascript">
      //an array of urls is required
      client = new EpiClient([
        "ws://some.epiquery2.server/sockjs/websocket",
        "ws://another.epiquery2.server/sockjs/websocket"
      ]);
      .... some code to use it
      </script>


The client supports automatic reconnection and the specification of multiple
epiquery2 servers for which it will handle failover in the case of errors
in the connection.

You can see actual usage examples in the test code, which is linked from
http://your.epiquery.server/static/test.html

## Definitions

* Query - Used to refer to the rendered result of processing a template in
response to a query message.  Specifically we use this to refer to the
resulting string as it is sent to the target server.  A Query as we've defined
here may well contain multiple queries against the target data source
resulting in multiple result sets.

* Active Query - A Query is considered to be active while it is being
processed by epiquery.  This time is specifically that which is bounded by
Query Begin and Query Complete messages.

* QueryRequest - An inbound request for epiquery to render and execute a
template against a specific connection.

* Data Source - A server from which epiquery is capable of retrieving data for
a query.

* Driver - the software (module) responsible for managing the translation of
a Query into the appropriate form for the destination service, and raising
events as data is returned.  It sends the query to the database and returns
results to epiquery.

* Named Connection - a connection to a single data source accessed by epiquery.

* epiquery - the application described within the repository hosting this README


## Supported data sources
* Microsoft SQL Server
* MySQL
* Microsoft SQL Server Analysis Services (MDX)
* File system

## Configuration

Configuration of epiquery is done entirely through environment variables, this
is done to simplify the deployment specifically within
[Starphleet](https://github.com/wballard/starphleet).  The configuration can
be done solely through environment variables or, as a convenience, epiquery
will source a file `~/.epiquery2/config` in which the variables can be specified.


* `TEMPLATE_REPO_URL` - (required) specifies the git repository from which the templates will be loaded
* `TEMPLATE_DIRECTORY` - (optional) Where the templates will be found, if not specified
the templates will be put into a directory named 'templates' within epiquery's working directory.
* `CONNECTIONS` - A space delimited list of names of environment variables which contain
the JSON encoded information needed to configure the various drivers.  Ya, gnarly.  We'll do this one through examples.
* `ENABLE_TEMPLATE_ACLS` - (optional) ACLs are enabled by default, however it's possible to disable them by setting
this to the string 'DISABLED'
* `HTTP_REQUEST_TIMEOUT_IN_SECONDS` - Number of seconds after which node will timeout connections, specifically this is used
to set [server.setTimeout(x)](https://nodejs.org/docs/latest-v5.x/api/http.html#http_request_settimeout_timeout_callback) which
defaults to 2 minutes both in node and here in epiquery2.

#### Sample Configuration (~/.epiquery2/config)
        export TEMPLATE_REPO_URL=https://github.com/intimonkey/epiquery-templates.git
        export TEMPLATE_DIRECTORY=~/Development/epiquery2/difftest/templates
        export CONNECTIONS="EPI_C_MSSQL EPI_C_FILE EPI_C_MYSQL EPI_C_RENDER EPI_C_MSSQL_RO"
        export EPI_C_FILE='{"driver":"file","config":{},"name":"file"}'
        export EPI_C_RENDER='{"driver":"render","config":{},"name":"render"}'
        export EPI_C_MSSQL='{"driver":"mssql","name":"mssql","config":{"server":"10.211.55.5","password":"PASSWORD","userName":"USER","options":{"port":1433}}}'
        export EPI_C_MYSQL='{"name":"mysql","driver":"mysql","config":{"host":"localhost","user":"root","password":""}}'
        export EPI_C_MSSQL_RO="{\"driver\":\"mssql\",\"name\":\"db250\",\"config\":{\"server\":\"${DATABASE_READONLY_SERVER}\",\"password\":\"${DATABASE_READONLY_PASSWORD}\",\"userName\":\"${DATABASE_READONLY_USER}\",\"options\":{\"port\":1433}}}"

## Interface

  The systems to which epiquery provides access are generally streaming data
sources.  The primary interface provided by epiquery is websockets as it allows for
an event based interface more compatable with the streaming data sources exposed.


#### Messages

##### query
Executes a Query using the data provided.

    {
      "templateName":"/test/servername",
      "connectionName"="mssql",
      "queryId":"",
      "data":{}
    }

* template - the path to the template desired.  This is relative to the root of the templates
  directory.
* queryId - A unique identifier used to refer to the query throughout it's Active period.
   It will be included with all messages generated during it's processing.
   It is the caller's responsability to generate a unique id for each query requested.
* data - An object that will be used as the template context when rendering.

#### Events

##### row
A message containing a single row of data from the execution of a query,
associated with the containing result set.

    {"message":"row", "queryId":"", "columns":{"col_name": "col_value"}}

##### beginrowset
Used to indicate that a result set has begun.  Some providers, given a particular query,
can return multiple result sets, this message indicates the start of a new result set from the
execution of a given query.  Individual query processing is synchronous, so while there is no
in built way to tie a particular section of a Query to a result set directly, each query contained
within the QueryRequest sent to the provider can result in a distinct result set, and thus the
emission of a 'beginrowset' message.

    {"message":"beginrowset", "queryId":""}

##### endrowset
For each result set that is started, there will be a corresponding end message sent.

    {"message":"endrowset", "queryId":""}

##### beginquery
Indicates that a particular query request has begun processing.  While a Query is active
other messages related to that query (having the same queryId) can and generally will
be raised.

    {"message":"beginquery", "queryId":""}

##### endquery
Indicates that a particular query has completed, all of it's data having been returned.  Indicates the
final stage of an Active Query, once this event is raised the associated Query is no longer considered
active.

    {"message":"endquery", "queryId":""}

#### Request Tracking

In order for support of various useful functionality the system will have the
concept of a QueryRequest.  The QueryRequest will track all the state info
about a request to execute a query, this will facilitate all sorts of things
around tracking a single request to execute a query as it is handled by the
system.  Specifically this is to help debugging as the concept of epiquery is
very concise and simple, it should support a robust handling of that functionality


##### Provided Drivers
* mssql - based on tedious, used to query an MS SQL Server instance
* mssql_o - based on tedious, used to query an MS SQL Server instance, this
  driver returns the results as an object instead of an array of key/value pairs
  this has some limitations (like not handling duplicate column names) but in
  many cases it's simpler to use.
* mysql - uses the mysql npm package
* file - Expects that the result of a template render will be a valid path.
  Given the result of the rendered template, it attempts to open the file
  indicated and stream the results line-at-a-time to the caller.  Each line
  comes through as a 'row' event.
* msmdx - allows for MDX querying of a Microsoft Analysis Server interface
* render - simply renders the template requested and returns the result
