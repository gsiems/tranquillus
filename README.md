# tranquillus

An experiment using REST for a reporting engine (vs. as a CRUD engine).
Primarily for database reporting. Can be used with other sources.

## Features

* Supports grouping of routes
 * Routes are grouped/organized into [modules](doc/Modules.md).
 * Each module is a perl module with configurations files

* Uses JSON or YAML files for configuring [routes](doc/Routes.md)
 * One configuration file per route.
 * The configuration is also the documentation.
 * Examples in the configuration become part of the "smoke test" for the route (TODO).

* "Standard" routes vs non-standard routes.

* Standard routes
 * Uses database query for the data.
 * The configuration has everything needed for building the DB query.
 * Postgres and Oracle supported (so far).
 * No additional (route specific) coding required.

* Non-standard routes
 * The configuration is the same as the standard case.
 * The configuration is still used to provide documentation and smoke tests.
 * Except that the functionality for the data route is custom.
 * Can proxy other services.

* Support for large and/or slow queries
 * Uses streaming to return the data.
 * Specified in the configuration.
 * Can use sets of query parameters to possibly improve query performance.

* Supports connections to multiple databases.
* The database connection to use can be defined at the global, module, or route level.
* Does not currently support Authentication/Authorization (TODO).
