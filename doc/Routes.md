
# Routes

The definition/configuration for a route is stored in a JSON or YAML
file in the directory for the module that the route belongs to. There
is one configuration file for each route that is defined. For example,
the "Foo" module would store it's configuration files under
"./lib/Tranquillus/Routes/Foo". JSON files require the .json extension
and YAML files may use either the .yml or .yaml extension. Files with
other extensions will not be treated as configuration files.

A route configuration is used for three main purposes:
* to provide the information for creating database queries,
* to generate the user documentations, and
* to generate tests for the route.

## Route Configuration

* **link:** The portion of the route URL that is unique to the
configured route.

* **desc:** The user friendly description of the route.

* **dictionary_link:** Optional. The link to the data dictionary for
the table/view in the From clause.

* **hide_doc:** Optional {1, 0}. Used to indicate if the documentation
should be hidden under normal circumstances. This can be overridden by
setting "show_hidden_doc" in the application environment configuration.

* **custom_data:** Optional {1, 0}. Used to indicate that the route
uses custom functionality to obtain/deliver the route data. If
custom_data is specified then there needs to be a custom function
defined for retrieving the route data.

* **examples:** The list of examples used to illustrate use of the
route. These examples are also used for smoke-testing the route. In
JSON, this is an array that consists of one or more example queries to
append to the route to both illustrate usage and to generate tests for
the route.

* **no_global_parms:** Optional {1, 0}. Used to disable all global
query parameters.

* **no_paging:** Optional {1, 0}. For routes that may return multiple
rows of data. Indicates whether or not to use paging in returning the
data. The default is to support paging through use of the "limit" and
"offset" query parameters. Setting this disables paging.

* **parms_optional:** Optional {1, 0}. Used to indicate that there are
no required parameters for the route. When there are one or more query
parameters defined for the route the default behavior is to require at
least one of the parameters to be supplied when querying the route.
Setting this disables requiring a parameter.

* **use_streaming:** Optional {1, 0}. Indicates that streaming should
be used to return data from the route. This is intended for routes that
are either slow retrieving the data or that return large amounts of
data.

* **database:** For database queries. Optional. The *connections* label
from the application configuration file that indicates the database
connection to use for retrieving the routes data. If no database is
specified then the default database will be used.

* **with:** For database queries. Optional. Defines the CTE "WITH" clause
to use in creating the database query.

* **from:** For database queries. The database table/view to select
from.

* **order_by:** For database queries. Optional. The order clause to use
for the "ORDER BY" clause of the query.

* **fields:** The list of fields of interest (query and/or result set
fields) used by the route.

    * **name:** The (JSON) name for the field

    * **desc:** The description of the field. Used in generating the
    user documentation.

    * **db_column:** The database column to query the data from. The
    existance of this parameter is also used for determining which
    fields show up in the result set.

    * **query_field:** Indicates that the field is to be available as a
    query parameter { 0 => not a query parameter, 1 => is a query
    parameter, 2 => is a required query parameter }. Default is 0.

    * **reference_href:** For query parameter fields. If the valid
    values for this field are defined by another route then this is
    used for defining the reference route.

    * **allow_many:** EXPERIMENTAL. For database queries, indicates
    that this field will accept a comma delimited list of query
    parameters. { 0 => do not accept a comma delimited list, 1 =>
    accept, and parse, the user input as a comma delimited list }.
    Default is 0.

    * **distinct:** For database queries, indicates that the query
    requires a "DISTINCT" clause {0, 1}. Default is to not require the
    DISTINCT clause (0).

    * **join_clause:** For database queries, if the field is a query field
    and requires a join to another table then the join syntax for that
    table goes here.

    * **where_exists:** For database queries where the query field maps to
    a one-to-many relationship for the query values, this contains the
    definition for the "WHERE EXISTS" clause.

    * **where_clause_col:** For database queries, if the where clause
    column is different than the db_column then that is specified here. ***Note***
    that if the where_clause_col is specified and no db_column
    is specified then the field becomes a query only field (is not included
    in the query results).

    * **where_type:** For query parameters. See [parm_parse_rules](parm_parse_rules.md).

    * **re:** For query parameters. Used in conjuction with
    "where_type". See [parm_parse_rules](parm_parse_rules.md).

* **version:** The version number for the route. Defaults to 1 if not
specifed.

* **deprecated:** Optional {1, 0}. Used to indicate that the route has
been deprecated {0 => not deprecated, 1 => deprecated}.

* **deprecated_by:** Optional. The route that the deprecated route has
been replaced by. The default is that there is no replacement route.

* **deprecated_until:** Optional. The sunset date at which the
deprecated route will cease to work. The format for the date is in the
form "yyyy-mm-dd" with a default of no date.

* **search_suggetion_size:** Optional. A non-standard route option used
for secifying the length of the list returned by the
do_search_suggestions function (Tranquillus::DB).

## Global parameters

While not defined in the route configuration, the following global
query parameters are available for all routes unless explicitly
disabled in the route configuration (no_global_parms, no paging).

* **fields:** The comma-separated-list of the field names to return
from the query. The default is to return all available fields.

* **format:** The desired return format. Valid formats are: {json,
jsonp, text, csv, xls, ods, and tab}. The default is json.

* **callback:** The JSONP callback function name (Note that format
needs to be "jsonp").

* **nullValue:** Value to substitute in place of null values. The
default is to return null values as "null" (per JSON.org).

* **limit:** The number of records to limit the result set to. Behaves
like the SQL standard LIMIT clause.

* **offset:** Used with Limit -- the record number to start retrieving
from. Behaves like the SQL standard OFFSET clause.
