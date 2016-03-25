package Tranquillus::DB::Query;
use Dancer2 appname => 'Tranquillus';

use DateTime;
use Tranquillus::Util;
use Tranquillus::DB::Connection;

sub prep_query {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );

    my ( $rt_config, $valid_parms ) = @_;

    my %query_parts = parse_query_parms( $rt_config, $valid_parms );

    # Check for errors before continuing
    if ( exists $query_parts{errors} && scalar @{ $query_parts{errors} } ) {
        Tranquillus::Util->return_error( 'BAD_QUERY', @{ $query_parts{errors} } );
    }

    if ( exists $rt_config->{with} ) {
        $query_parts{with} = $rt_config->{with};
    }
    if ( exists $rt_config->{order_by} ) {
        $query_parts{order_by} = $rt_config->{order_by};
    }

    my %query = generate_query( $rt_config, $valid_parms, \%query_parts );

    #delete $query_parts{$_} for ( keys %query_parts );
    #undef %query_parts;

    # Check for errors before continuing
    if ( exists $query{errors} && scalar @{ $query{errors} } ) {
        Tranquillus::Util->return_error( 'BAD_QUERY', @{ $query{errors} } );
    }

    return \%query;
}

sub generate_query {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $rt_config, $valid_parms, $query_parts ) = @_;

    my $limit;
    my $offset;
    my $paging = ( exists $rt_config->{no_paging} && $rt_config->{no_paging} ) ? 0 : 1;

    # Determine which fields are available for selecting
    my %selectable_cols;
    foreach my $field ( @{ $rt_config->{fields} } ) {
        my $name = $field->{name};
        my $db_column = ( exists $field->{db_column} ) ? $field->{db_column} : undef;
        $selectable_cols{$name} = $field if ($db_column);
    }

    # Determine which fields to select
    my @aliases;
    if ( params->{fields} ) {
        foreach my $name ( split /\s*,\s*/, params->{fields} ) {
            if ( exists $selectable_cols{$name} ) {
                push @aliases, $name;
            }
        }
    }
    elsif ( exists $rt_config->{field_order} ) {
        foreach my $name ( @{ $rt_config->{field_order} } ) {
            if ( exists $selectable_cols{$name} ) {
                push @aliases, $name;
            }
        }
    }
    else {
        foreach my $field ( @{ $rt_config->{fields} } ) {
            my $name = $field->{name};
            if ( exists $selectable_cols{$name} ) {
                push @aliases, $name;
            }
        }
    }

    my @columns =
        map { 'a.' . $selectable_cols{$_}{db_column} . ' AS "' . $_ . '"' } (@aliases);

    # Only do distinct if one of the supplied query parameters requires it
    my $distinct = $query_parts->{distinct} || '';

    # Determine the need for an inner/outer select.
    # This is only needed if we are paging or setting row number limits

    if ( exists $selectable_cols{'q'} ) {
        $limit  = 5;
        $offset = 0;
    }
    elsif ($paging) {
        if (   exists $valid_parms->{limit}
            && $valid_parms->{limit} > 0
            && $valid_parms->{limit} =~ m/^[0-9]+$/ )
        {
            $limit = $valid_parms->{limit};
        }
        if (   exists $valid_parms->{offset}
            && $valid_parms->{offset} > 0
            && $valid_parms->{offset} =~ m/^[0-9]+$/ )
        {
            $offset = $valid_parms->{offset};
        }
    }

    # TODO: If we're going to allow limits/offsets then some additional
    # study at "use the index luke" should be encouraged.

    #
    my @errors;

    if ( exists $query_parts->{errors} && @{ $query_parts->{errors} } ) {
        @errors = @{ $query_parts->{errors} };
    }

    # SELECT, FROM, JOIN, WHERE, and ORDER BY clauses
    my $with = $query_parts->{with} || '';
    my $select  = 'SELECT ' . $distinct . join( ', ', @columns );
    my $from    = $query_parts->{from};
    my @where_a = @{ $query_parts->{where_a} };
    my $where   = ( scalar @where_a ) ? ' WHERE ' . join ' AND ', @where_a : '';

    # TODO: add user defined order by?
    my $order_by = $query_parts->{order_by} || '';

    my $db_engine = Tranquillus::DB::Connection->get_engine( $rt_config->{database} );
    my $query;
    if ( $limit || $offset ) {
        $limit  ||= 0;
        $offset ||= 0;

        if ( $db_engine && $db_engine eq 'Oracle' ) {
            $query = "SELECT * FROM ( $with $select, rownum AS rn $from $where $order_by )";

            my @ary;
            push @ary, "rn > $offset"           if ($offset);
            push @ary, "rn <= $limit + $offset" if ($limit);

            if (@ary) {
                $query .= ' WHERE ' . join( ' AND ', @ary );
            }
        }
        if ( $db_engine && $db_engine eq 'Pg' ) {
            $query = "SELECT * FROM ( $with $select $from $where $order_by )";

            my @ary;
            push @ary, "OFFSET $offset" if ($offset);
            push @ary, "LIMIT  $limit"  if ($limit);

            if (@ary) {
                $query .= ' WHERE ' . join( ' ', @ary );
            }
        }
    }
    else {
        $query = "$with $select $from $where $order_by";
    }

    my $parms_are_optional = $rt_config->{parms_optional} || 0;

    my %return = (
        vars           => $query_parts->{vars},
        valid_parms    => $valid_parms,
        query          => $query,
        column_names   => \@aliases,
        db_engine      => $db_engine,
        database       => $rt_config->{database},
        no_paging      => ($paging) ? 0 : 1,
        paging         => $paging,
        parms_optional => $parms_are_optional,
    );

    if (@errors) {
        $return{errors} = \@errors;
    }

    return %return;
}

sub parse_query_parms {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $rt_config, $valid_parms ) = @_;

    my $distinct;
    my @vars;
    my @from_clause;
    my @errors;
    my @where_a;
    my $query_field_count = 0;
    if ( $rt_config->{from} ) {
        push @from_clause, $rt_config->{from};
    }

    my %parsed_parms;

    foreach my $field ( @{ $rt_config->{fields} } ) {

        my $name        = $field->{name};
        my $query_field = ( exists $field->{query_field} ) ? $field->{query_field} : 0;
        my $in_query    = ( exists $valid_parms->{$name} );
        my $where_col =
              ( exists $field->{db_column} )        ? 'a.' . $field->{db_column}
            : ( exists $field->{where_clause_col} ) ? $field->{where_clause_col}
            :                                         undef;

        # We only care about the fields that:
        # a. are named,
        next unless ($name);

        # b. maps to a db column or a where clause,
        next unless ($where_col);

        # c. are flagged as queryable, and
        next unless ($query_field);
        $query_field_count++;

        # d. the user is querying by
        next unless ($in_query);

        my $type = ( exists $field->{where_type} ) ? $field->{where_type} : 'text';
        my $re   = ( exists $field->{re} )         ? $field->{re}         : undef;
        my $allow_many  = ( exists $field->{allow_many} && $field->{allow_many} ) ? 1               : 0;
        my $allow_limit = ( exists $field->{limit} )                              ? $field->{limit} : 100;
        my %parsed_parm = parse_query_parm(
            where_col   => $where_col,
            parm        => $valid_parms->{$name},
            type        => $type,
            allow_many  => $allow_many,
            allow_limit => $allow_limit,
            re          => $re
        );

        if ( scalar @{ $parsed_parm{vars} } ) {
            $parsed_parms{$name} = 1;

            if ( exists $field->{distinct} && $field->{distinct} ) {
                $distinct = 'DISTINCT ';
            }

            my $exists_clause = ( exists $field->{where_exists} ) ? $field->{where_exists} : '';
            if ($exists_clause) {
                my $clause = ' EXISTS (' . join( ' AND ', $exists_clause, @{ $parsed_parm{where} } ) . ' ) ';
                push @where_a, $clause;
            }
            else {
                push @where_a, $_ for ( @{ $parsed_parm{where} } );
            }

            if ( exists $field->{join_clause} ) {
                push @from_clause, $field->{join_clause};
            }

            push @vars, $_ for ( @{ $parsed_parm{vars} } );
        }
        else {
            push @errors, "Error while parsing the \"$name\" query parameter.";
        }
    }

    # Ensure that, if one or more parameters are required,
    # one or more parameters were supplied.
    if ( ( $query_field_count > 0 ) && ( scalar @vars == 0 ) ) {
        unless ( exists $rt_config->{parms_optional} && $rt_config->{parms_optional} ) {
            push @errors, "One or more query parameters are required.";
        }
    }

    # Ensure that any required parameters have been supplied (and passed the parm parser)
    foreach my $field ( @{ $rt_config->{fields} } ) {
        if ( exists $field->{query_field} && $field->{query_field} > 2 ) {
            my $name = $field->{name};
            unless ( exists $parsed_parms{$name} ) {
                push @errors, "A required parmeter ($name) was not supplied (or had validation issues).";
            }
        }
    }

    my $from = ( scalar @from_clause ) ? join( ' ', @from_clause ) : '';

    my %return;

    $return{from}     = $from;
    $return{distinct} = $distinct;
    $return{where_a}  = \@where_a;
    $return{vars}     = \@vars;
    if ( scalar @errors ) {
        $return{errors} = \@errors;
    }

    return %return;
}

sub parse_query_parm {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my %args = @_;

    my $where_col   = $args{where_col};
    my $parm        = $args{parm};
    my $type        = $args{type};
    my $allow_many  = $args{allow_many};
    my $allow_limit = $args{allow_limit};
    my $re          = $args{re};

    my @vars;
    my @where_a;
    my $enable_join_clause;

    # "Numeric integer" fields
    if ( $type eq 'pos_int' ) {

        $re ||= '[^0-9]';

        # The idea here is to allow selecting a limited list of ids
        # (assuming that the DB is using synthetic keys)
        my @tokens = _tokenize_var( $parm, '\s*,\s*', $re, $allow_limit );
        if (@tokens) {
            if ( scalar @tokens == 1 ) {
                push @where_a, "$where_col = ?";
            }
            else {
                my @a = map { '?' } @tokens;
                push @where_a, "$where_col IN (" . join( ', ', @a ) . ')';
            }
            foreach my $token (@tokens) {
                push @vars, $token;
            }
            $enable_join_clause = 1;
        }
    }

    # Number fields
    elsif ( $type =~ m/_number$/ ) {

        # Number fields (default is to match the number)
        my ($operator) = $type =~ m/^([^_]+)_/;
        $operator ||= '=';
        $parm =~ s/[^0-9.]//;
        if ($parm) {
            my $where = "$where_col $operator ?";
            push @where_a, $where;
            push @vars,    $parm;
            $enable_join_clause = 1;
        }
    }

    # Date fields
    elsif ( $type =~ m/date$/ ) {

        # Date fields (default is to match the date) if there are two
        # dates then is is assumed that a date range is desired.

        my ( $begin, $end ) = split /\s*,\s*/, $parm;

        if ( $parm =~ m/,/ ) {
            if ( $begin && $end ) {
                $begin = parse_date($begin);
                $end   = parse_date($end);
                if ( $begin && $end ) {
                    my $where =
                        "$where_col BETWEEN " . "to_date ( ? , 'yyyy-mm-dd' ) " . "AND to_date ( ? , 'yyyy-mm-dd' )";
                    push @where_a, $where;
                    push @vars,    $begin;
                    push @vars,    $end;
                    $enable_join_clause = 1;
                }
            }
            elsif ($begin) {
                $begin = parse_date($begin);
                if ($begin) {
                    my $where = "$where_col >= to_date ( ? , 'yyyy-mm-dd' )";
                    push @where_a, $where;
                    push @vars,    $begin;
                    $enable_join_clause = 1;
                }
            }
            elsif ($end) {
                $end = parse_date($end);
                if ($end) {
                    my $where = "$where_col <= to_date ( ? , 'yyyy-mm-dd' )";
                    push @where_a, $where;
                    push @vars,    $end;
                    $enable_join_clause = 1;
                }
            }
        }
        elsif ($begin) {
            my ($operator) = $type =~ m/^([^_]+)_/;
            $operator ||= '=';

            $begin = parse_date($begin);
            if ($begin) {
                my $where = "$where_col $operator to_date ( ? , 'yyyy-mm-dd' )";
                push @where_a, $where;
                push @vars,    $begin;
                $enable_join_clause = 1;
            }
        }
    }

    # "Like" or "Starts with" text fields matching
    elsif ( $type =~ m/like$/ || $type =~ m/starts$/ ) {

        # ('' => case sensitive, cu => cast upper,
        #   cl => cast lower, iu => is already upper,
        #   il => is already lower)

        my $prefix = ( $type =~ m/like$/ ) ? '%' : '';

        if ( $type =~ m/^.l_/ ) {
            $re ||= '[^a-z0-9]+';
            $parm = lc $parm;
        }
        elsif ( $type =~ m/^.u_/ ) {
            $re ||= '[^A-Z0-9]+';
            $parm = uc $parm;
        }
        else {
            $re ||= '[^A-Za-z0-9]+';
        }

        my @ary = split /$re/, $parm;

        my $where =
              ( $type =~ m/^cl_/ ) ? "lower ($where_col) like ?"
            : ( $type =~ m/^cu_/ ) ? "upper ($where_col) like ?"
            :                        "$where_col like ?";

        foreach my $token (@ary) {
            next unless ($token);
            push @where_a, $where;
            push @vars,    $prefix . $token . '%';
            $enable_join_clause = 1;
        }
    }

    # "Regular" text fields matching
    elsif ( $type =~ m/text$/ ) {

        # ('' => case sensitive, cu => cast upper,
        #   cl => cast lower, iu => is already upper,
        #   il => is already lower)

        if ( $type =~ m/^.l_/ ) {
            $re ||= '[^a-z0-9]+';
            $parm = lc $parm;
        }
        elsif ( $type =~ m/^.u_/ ) {
            $re ||= '[^A-Z0-9]+';
            $parm = uc $parm;
        }
        else {
            $re ||= '[^A-Za-z0-9]+';
        }

        my $where =
              ( $type =~ m/^cl_/ ) ? "lower ($where_col) "
            : ( $type =~ m/^cu_/ ) ? "upper ($where_col) "
            :                        "$where_col ";

        my @tokens = _tokenize_var( $parm, '\s*,\s*', $re, $allow_limit );
        if (@tokens) {
            if ( scalar @tokens == 1 ) {
                push @where_a, "$where = ?";
            }
            else {
                my @a = map { '?' } @tokens;
                push @where_a, "$where IN (" . join( ', ', @a ) . ')';
            }
            foreach my $token (@tokens) {
                push @vars, $token;
            }
            $enable_join_clause = 1;
        }
    }

    my %return = (
        where       => \@where_a,
        vars        => \@vars,
        join_clause => $enable_join_clause,
    );

    return %return;
}

sub parse_date {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($date) = @_;
    my %months = (
        'jan' => 1,
        'feb' => 2,
        'mar' => 3,
        'apr' => 4,
        'may' => 5,
        'jun' => 6,
        'jul' => 7,
        'aug' => 8,
        'sep' => 9,
        'oct' => 10,
        'nov' => 11,
        'dec' => 12,
    );

    my ( $yr, $mon, $mday );

    # 2015-12-16  |  2015-12-16 21:24:56  |  2015-12-16T21:24:56
    if ( $date =~ m/^([0-9]{2,4}?)[ -]+([0-9]{1,2}?)[ -]+([0-9]{1,2}?)/ ) {
        #( $yr, $mon, $mday ) = ( $1, $2, $3 );
        ( $yr, $mon, $mday ) = split /[ T-]/, uc $date;
    }

    # 16 December 2015  |  16 December, 2015
    # 16 Dec 2015       |  16 Dec, 2015         |  16-Dec-2015
    elsif (
        $date =~ m/^([0-9]{1,2}?)[ -]+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[, -]+([0-9]{2,4}?)$/i )
    {
        ( $mday, $mon, $yr ) = ( $1, $months{ substr( lc $2, 0, 3 ) }, $3 );
    }

    # December 16 2015  | December 16, 2015
    # Dec 16 2015       | Dec 16, 2015          | Dec-16-2015
    elsif (
        $date =~ m/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[ -]+([0-9]{1,2}?)[, -]+([0-9]{2,4}?)$/i )
    {
        ( $mon, $mday, $yr ) = ( $months{ substr( lc $1, 0, 3 ) }, $2, $3 );
    }

    # Wed Dec 16 21:24:56 CST 2015
    if ( $date =~
        m/^[A-Z]\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+[0-9]:[0-9]:[0-9]\s+[A-Z]\s+([0-9]{2,4}?)$/i
        )
    {
        ( $mday, $mon, $yr ) = ( $months{ substr( lc $1, 0, 3 ) }, $2, $3 );
    }

    # 12/16/2015
    elsif ( $date =~ m|^([0-9]{1,2}?)/([0-9]{1,2}?)/([0-9]{2,4}?)$| ) {
        ( $mon, $mday, $yr ) = ( $1, $2, $3 );
    }

    return undef unless ( defined $yr && $mon && $mday );

    # Y2K
    if ( $yr >= 0 && $yr < 50 ) {
        $yr += 2000;
    }
    elsif ( $yr < 100 ) {
        $yr += 1900;
    }

    # Validate that it is a good date
    # Accepting "31 Feb 2015" as a valid date isn't desirable

    # 2016-03-24 Quote the $yr, $mon, $mday so that "08" doesn't trigger
    # an "Illegal octal digit '8' at (eval 24) line 4, at end of line" error
    eval qq{
        DateTime->new(
            year       => "$yr",
            month      => "$mon",
            day        => "$mday",
        );
    };
    return undef if ($@);

    # Return the date string in ISO format
    $date = sprintf( "%04d-%02d-%02d", $yr, $mon, $mday );
    return $date;
}

sub _tokenize_var {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );

    my ( $var, $splitter, $scrubber, $allow_limit ) = @_;

    my @tokens;
    if ($allow_limit) {
        @tokens = split /$splitter/, $var;
        if ( scalar @tokens > $allow_limit ) {
            @tokens = @tokens[ 0 .. $allow_limit - 1 ];
        }
    }
    else {
        @tokens = ($var);
    }

    my @vars;
    foreach my $token (@tokens) {
        $token =~ s/$scrubber//g;
        if ( defined $token && length($token) > 0 ) {
            push @vars, $token;
        }
    }

    return @vars;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true
