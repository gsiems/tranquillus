
* Add JSON option to the documentation (return doc as JSON)
* Add config based smoke tests
* Auth
    * Authentication support
        * Javascript Web Tokens (JWT)
        * Pluggable Authentication backends
            * Database
            * LDAP/AD
            * OAuth
            * etc.
            * Support for per user backends, or cascading backends...
        * Password reset support (depending on authentication backend used)
        * Add, edit, delete users using REST
    * Thoughts on authorization support
        * Role based
        * Suppport row based authorization
* More example modules/routes
* Development environment documentation (what's available and how it differs from non-devel)
* Add strict vs. non-strict parameter checking-- generate a 50x error on invalid parameters or a "friendlier" error message
* Built in support for Postgresql function based queries "`select ... from function ( arg [, arg[, ... ]]`" (can currently be done using custom data functions.
