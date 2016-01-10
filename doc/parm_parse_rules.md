
# Parameter parsing rules

Query parameters passed to a route get "sanitized" as part of creating
a database query. One reason for this is minimize the opportunity for
damage from malformed queries. Another reason is to help string
searches to be more likely to return useful results.

There are two configuration parameters used for defining how query
parameters are to be parsed, "where_type" and "re".

* **where_type:** This defines how the where clause for the query
parameter should be processed.

* **re:** This is the regular expression used for sanitizing query
parameters. When the where_type parameter is some form of "like" then
this defines how the query parameter will be split. Each split token
becomes a "LIKE" clause in the query "WHERE" clause.

Parameter parsing rules may be defined in one of two places. The
"where_type" and "re" configuration parameters may be specified at the
field level in the route configurations, or in the parm_parse_rules
function in the module definition.

## Module parm_parse_rules

When used in the module definition, the rule definitions would look like:

```
sub parm_parse_rules {
    my %parm_parse_rules = (
        fieldName1 => { where_type => 'iu_text', re => '[^A-Z0-9-]', },
        fieldName2 => { where_type => '>=_date', },
        fieldName3 => { where_type => 'pos_int', },
    );
    return \%parm_parse_rules;
}
```

## Valid where_type values

* **pos_int:** Treat the parameter like a positive integer and ensure
that the supplied value consists solely of the digits 0-9.

* **number:** Treat the parameter like a number. This can include a
prefix plus underscore to change the behavior. Valid prefixes are:

    * *=:* Equal to. This is the default behavior.
    * *>=:* Greater than, or equal to, the provided number.
    * *>:* Greater than the provided number.
    * *<=:* Less than, or equal to, the provided number.
    * *<:*  Less than the provided number.
    * *<>:* Not equal to the provided number.

* **date:** Treat the parameter like a date. This can include a prefix
plus underscore to change the behavior. Additionally, date ranges may
be defined by supplying two, comma separated, dates (no prefix). This
becomes "WHERE date_column BETWEEN date1 AND date2". Valid prefixes
are:

    * *=:* Equal to. This is the default behavior.
    * *>=:* Greater than, or equal to, the provided date.
    * *>:* Greater than the provided date.
    * *<=:* Less than, or equal to, the provided date.
    * *<:*  Less than the provided date.
    * *<>:* Not equal to the provided date.

* **text:** Treat the parameter as plain text and match the entire
field. This can include a prefix plus underscore to specify the case
sensitivity of the match. Valid prefixes are:

    * //cu:// Cast the parameter and the field to upper case "WHERE upper (column_name) = upper (parameter)".
    * //cl:// Cast the parameter and the field to lower case "WHERE lower (column_name) = lower (parameter)".
    * //iu:// Cast the parameter to upper case (the field is already upper case) "WHERE column_name = upper (parameter)".
    * //il:// Cast the parameter to lower case (the field is already lower case) "WHERE column_name = lower (parameter)".

* **like:** The same as "text" above except that the match becomes
anywhere in the field -- the same as the SQL LIKE clause.

* **starts:** Starts with. The same as "like" above except that the
match is anchored to the beginning of the field.

