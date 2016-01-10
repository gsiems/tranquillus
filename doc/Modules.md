
# Modules

* An application consists of one or more modules.
* A module consists of one or more [routes](Routes.md).
* Each module is implemented by a perl package of the (hopefully) same
name. For example, the "Foo" module would be declared as
"package Tranquillus::Routes::Foo" and would have a filename of Foo.pm
* Module files are located under the lib/Tranquillus/Routes directory.
* There are sample modules to illustrate the concept.
* The simplest module has variables defining the module name,
description, and "prefix" where prefix defines the portion of the route
URLs specific to the module.
* Modules also provide a [parm_parse_rules](parm_parse_rules.md)
function that defines the rules for parsing the query parameters for
the routes.
* Modules may also have custom data functions for those routes that are
not of the standard query variety.
