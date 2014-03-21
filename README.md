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

* epiquery - this application described within the repository hosting this README


## Supported data sources
* Microsoft SQL Server 
* MySQL
* Microsoft SQL Server Analysis Services (MDX)
* File system

## Configuration 

Configuration of epiquery is done entirely through environment variables, this
is done to simplify the deployment specifically within [Starphleet](https://github.com/wballard/starphleet).  The configuration can be done solely through environment variables or,
as a convenience, epiquery will source a file ~/.epiquery2/config in which the 
variables can be specified.


* `TEMPLATE_REPO_URL` - (required) specifies the git repository from which the templates will be loaded
* `TEMPLATE_DIRECTORY` - (optional) Where the templates will be found, if not specified
the templates will be put into a directory named 'templates' within epiquery's working directory.
* `CONNECTIONS` - A space delimited list of names of environment variables which contain
the JSON encoded information needed to configure the various drivers.  Ya, gnarly.  We'll do this one through examples.

### Example Configuration (~/.epiquery2/config)
        export TEMPLATE_REPO_URL=https://github.com/intimonkey/epiquery-templates.git
        export TEMPLATE_DIRECTORY=~/Development/epiquery2/difftest/templates
        export CONNECTIONS="EPI_C_RENDER2 EPI_C_MSSQL EPI_C_FILE EPI_C_MYSQL EPI_C_RENDER EPI_C_503_MDX"
        export EPI_C_FILE='{"driver":"file","config":{},"name":"file"}'
        export EPI_C_RENDER='{"driver":"render","config":{},"name":"render"}'
        export EPI_C_MSSQL='{"driver":"mssql","name":"mssql","config":{"server":"10.211.55.5","password":"GLGROUP_LIVE","userName":"GLGROUP_LIVE","options":{"port":1433}}}'
        export EPI_BAD_MSSQL='{"driver":"mssql","name":"bad_mssql","config":{"server":"10.55.5","password":"GLGROUP_LIVE","userName":"GLGROUP_LIVE","options":{"port":1433}}}'
        export EPI_C_MYSQL='{"name":"mysql","driver":"mysql","config":{"host":"localhost","user":"root","password":""}}'
        export EPI_C_MSSQL_GLGLIVE250="{\"driver\":\"mssql\",\"name\":\"db250\",\"config\":{\"server\":\"${DATABASE_GLGLIVE_READONLY_SERVER}\",\"password\":\"${DATABASE_GLGLIVE_READONLY_PASSWORD}\",\"userName\":\"${DATABASE_GLGLIVE_READONLY_USER}\",\"options\":{\"port\":1433}}}"

## Interface

  The systems to which epiquery provides access are generally streaming data
sources.  The only interface epiquery supports is websockets as it allows for simple
event based interface more compatable with the streaming data sources accessed
through epiquery.

#### Messages

##### Query
Executes a Query using the data provided.  

    {"message":"query", "template":"/path/to/template.mustache", "queryId":"", "data":{}}

* template - the path to the template desired.  This is relative to the root of the templates
  directory.
* queryId - A unique identifier used to refer to the query throughout it's Active period. It will be included with all messages generated during it's processing. It is the caller's responsability to generate a unique id for each query requested.
* data - An object that will be used as the template context when rendering.

##### Row
A message containing a single row of data from the execution of a query, associated with a containing result set.

    {"message":"row", "queryId":"", "columns":{"col_name": "col_value"}}

##### ResultSet Begin
Used to indicate that a result set has begun.  Some providers, given a particular query, 
can return multiple result sets, this message indicates the start of a new result set from the
execution of a given query.  Individual query processing is synchronous, so while there is no
in built way to tie a particular section of a Query to a result set directly, each query contained
within the Query sent to the provider can result in a distinct result set, and thus the 
emission of a 'ResultSet Begin' message.

    {"message":"resultset_begin", "queryId":""}

##### ResultSet End
For each result set that is started, there will be a corresponding end message sent.

    {"message":"resultset_end", "queryId":""}

##### Query Begin
Indicates that a particular query request has begun processing.  While a Query is active
other messages related to that query (having the same queryId) can and generally will
be raised.

    {"message":"query_begin", "queryId":""}

##### Query Complete
Indicates that a particular query has completed, all of it's data having been returned.  Indicates the 
final stage of an Active Query, once this event is raised the associated Query is no longer considered
active.

    {"message":"query_complete", "queryId":"", "rowCount":3}

### Query Driver Interface

executeQuery(text, rowCallback, recordsetCallback)

### Design thoughts

#### Request Tracking

In order for support of various useful functionality the system will have the
concept of a QueryRequest.  The QueryRequest will track all the state info
about a request to execute a query, this will facilitate all sorts of things
around tracking a single request to execute a query as it is handled by the
system.  Specifically this is to help debugging as the concept of epiquery is
very concise and simple, it should support a robust handling of that functionality


#### Data Source 'Drivers'

Epiquery simply provides a consistent interface to query data from various
disparate datasources (often Relational, and almost always best treated as 
streaming data sources).  To support this and allow for ease of extending
the system to support other datasources epiquery will support individual
Drivers handling the interface to the various supported data sources.  Epiquery
will explicitly support a set of built in drivers and handling of 'after market'
or user created drivers as well to facilitate extension to support additonal
datasources.

##### Provided Drivers
* mssql 
* mysql
* file - Expects that the result of a template render will be a valid path.  
  Given the result of the rendered template, it attempts to open the file
  indicated and stream the results line-at-a-time to the caller.  Each line
  comes through as a 'row' event.
* msmdx
* render - simply renders the template requested and returns the result

#### Connections

Epiquery supports configuration of multiple, named, connections to be used
when executing a QueryRequets.  In addition it allows for specification of
all required connection information within the request, allowing for connection
to arbitrary supported data sources.
