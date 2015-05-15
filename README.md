## I don't care, how do I use it.
  
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

## Local Development
That is, _I do care, how do I get this to run locally?_

1. Create a configuration file `~/.epiquery2/config` with the following
   environment variables defined, replacing with appropriate
   values.
  ```
  export TEMPLATE_REPO_URL=git@github.com:some_user/some_repo.git
  export CONNECTIONS="some_conn_name"
  export some_conn_name="{\"name\":\"some_db\",\"driver\":\"mssql\",\"config\":{\"userName\":\"some_user\",\"password\":\"some_password\",\"server\":\"host.of.some.server.com\",\"port\":\"some_port\"}}"
  export PORT=some_other_port
  ``` 
1. Run the following commands in the root of this repo:
  ```
  npm install -g supervisor
  npm install
  make watch
  ```
1. Test to be sure everything works by hitting the following in a
   browser: http://localhost:some_other_port/static/tests.html

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

#### Sample Configuration (~/.epiquery2/config)
        export TEMPLATE_REPO_URL=https://github.com/intimonkey/epiquery-templates.git
        export TEMPLATE_DIRECTORY=~/Development/epiquery2/difftest/templates
        export CONNECTIONS="EPI_C_MSSQL EPI_C_FILE EPI_C_MYSQL EPI_C_RENDER EPI_C_MSSQL_RO"
        export EPI_C_FILE='{"driver":"file","config":{},"name":"file"}'
        export EPI_C_RENDER='{"driver":"render","config":{},"name":"render"}'
        export EPI_C_MSSQL='{"driver":"mssql","name":"mssql","config":{"server":"10.211.55.5","password":"GLGROUP_LIVE","userName":"GLGROUP_LIVE","options":{"port":1433}}}'
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


