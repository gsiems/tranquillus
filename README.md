# tranquillus

An experiment in RESTful reporting.

## Initially

* REST for reporting (vs. CRUD).

* Primarily for database reporting. Can be used with other sources.

* Routes are grouped/organized into modules.
 * Each module is a perl module with configurations files

* For the "standard" case, everything runs off the route configuration.
 * One configuration file per route.
 * Can be either JSON or YAML.
 * The configuration has everything needed for building the DB queries.
 * The configuration is also the documentation.
 * Examples in the configuration become part of the "smoke test".

* Non-standard cases still require a configuration file
 * The configuration is the same as the standard case.
 * The configuration is still used to provide documentation and smoke tests.
 * Except that the functionality for the data route is custom.

* Postgres and Oracle supported (so far).
* Supports connections to multiple databases.
* The database connection to use can be defined at the global, module, or route level.
