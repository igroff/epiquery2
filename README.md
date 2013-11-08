## Definitions

* Query - Used to refer to the rendered result of processing a template in response to a query message. 
  Specifically we use this to refer to the resulting string as it is sent to the target server.  A Query
  as we've defined here may well contain multiple queries against the target data source resulting in 
  multiple result sets.
* Active Query - A Query is considered to be active while it is being processed by epiquery.  This 
  time is specifically that which is bounded by Query Begin and Query Complete messages.

## Supported data sources
* Microsoft SQL Server - as supported by the tedious npm package (although it has been patched
for a date issue). Driver name: mssql
* MySQL - Driver name: mysql

## Configuration 

Config, JSON object accessible via environment variable `EPIQUERY_CONFIG` as
either the object itself (JSON) or a file containing JSON.

#### Configuration Structure
Provides the configuration information for an epiquery instance, a skeleton
with all options is listed below:

    {
      "connections":[],
      "templateDir":"",
      "listeningPort":8080
    }

##### Connection Config
Named connections are mapped to inbound requests, determining what connection will be used to
process the rendered query template.  Connection names are indicated by providing the name of the
desired connection in the inbound request, see below for details.

###### Connection Configuration Element
Individual (named) connections are configured using a connection element, as a member of the
connections list in the epiquery configuration object.  The config property of the element is
configuration data that is specific to the driver.

    {
      "name":"",
      "driver":"",
      "config":{}
    }

#### Sample Configuration
    {
      "connections":[
        {"name":"sql__old","driver":"mssql","config": {"user":"", "password":"", "host":"", "port":""}},
        {"name":"sql_conn","driver":"mssql","config": {"user":"", "password":"", "host":"", "port":""}},
        {"name":"sql_con2","driver":"mssql","config": {"user":"", "password":"", "host":"", "port":""}},
        {"name":"mysql","driver":"mysql","config": {"user":"", "password":"", "host":"", "port":""}}
      ],
      "templateDir":"",
      "httpPort":8080
    }
 
## Interface

  The systems to which epiquery provides access are generally streaming data
sources.  The only supported interface is websockets as it allows for simple
event based interface more compatable with streaming data

##### Compatability
    As a convenience there is a veneer that maps the underlying socket protocol into a REST like interface. The REST interface is backwards compatible with an older epiquery interface offering less functionality and being quite a bit less sophisticated than the socket interface.  

    New uses of the system should be based on the socket interface and have nothing to do with the REST interface. The REST interface is solely for backwards compatability and is lacking in several areas including missing a streaming response, which makes it a poor choice for large data sets as the whole response will be buffered before responding.
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

execute_query(text, row_callback, recordset_callback)

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
