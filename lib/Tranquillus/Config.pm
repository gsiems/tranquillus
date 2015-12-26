package Tranquillus::Config;

use Dancer2 appname => 'Tranquillus';
use JSON ();
use Data::Dumper;

my $data_root = ( exists config->{data_root} ) ? config->{data_root} : '/api/vVERSION';
my $documentation_root =
    ( exists config->{documentation_root} )
    ? config->{documentation_root}
    : '/api/doc/vVERSION';

sub read_configs {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $config_dir, $arg_parse_rules, $module_name, $module_prefix, $description, $hide_doc ) = @_;

    # Ensure that there is *something* for the description
    $description ||= 'TODO';

    # Use the length of the descriptions of modules, routes and fields
    # aid to encouraging some minimally viable (or much better) level of
    # documentation. While minimum length is a lousy metric it is quick,
    # easy, and should help the documenters find the routes that need
    # help in that area.

    # Moderately bogus measure of how acceptable the module description is
    my $wc = () = $description =~ m/([^\s]\s+[^\s])/g;
    $wc += 1;
    my $pct_module_desc = ( $wc > 7 ) ? 100 : int( $wc * 100 / 7 );

    my $route_desc_count = 0;
    my $field_desc_count = 0;
    my $field_count      = 0;

    my @routes;

    if ( -d $config_dir ) {
        opendir( my $dh, $config_dir );
        if ($!) {
            warn "Can't opendir $config_dir: $!";
        }
        else {
            my @config_files =
                grep { -f $_ }
                grep { $_ =~ m/\.(json|yml|yaml)$/i }
                map  { "$config_dir/$_" } readdir($dh);
            closedir $dh;

            foreach my $file (@config_files) {
                my $config = _slurp($file);
                my $h;
                if ( $file =~ m/\.json$/i ) {
                    $h = JSON::from_json( $config, { utf8 => 1 } );
                }
                else {
                    $h = YAML::Load( decode( 'UTF-8', $config ) );
                }

                # Ensure that there is a version number for the route
                $h->{version} ||= 1;

                # Ensure that *some* description exists
                $h->{desc} ||= 'TODO';

                # Moderately bogus measure of how acceptable the
                # route description is
                my $wc = () = $h->{desc} =~ m/([^\s]\s+[^\s])/g;
                $h->{pct_route_desc} = ( $wc > 3 ) ? 100 : 0;
                $route_desc_count++
                    if ( $wc > 3 );    # Because "Valid values for x" is 3

                #
                $h->{module_name}   = $module_name;
                $h->{module_prefix} = $module_prefix;
                $h->{database} ||= 'default';

                my $doc_route = join '/', $documentation_root, $module_prefix, $h->{link};
                $doc_route =~ s/VERSION/$h->{version}/;
                $h->{doc_route} = $doc_route;

                my $data_route = join '/', $data_root, $module_prefix, $h->{link};
                $data_route =~ s/VERSION/$h->{version}/;
                $h->{data_route} = $data_route;

                #
                $h = prime_config_fields( $h, $arg_parse_rules );

                my $no_paging = ( exists $h->{no_paging} ) ? $h->{no_paging} : 0;
                my $no_params = ( exists $h->{no_params} ) ? $h->{no_params} : 0;

                my @gp = global_query_parms( $no_paging, $no_params );

                if (@gp) {
                    $h->{format_fields} = \@gp;
                }

                if ( config->{environment} eq 'development' ) {

                    # TODO: If the configuration uses a 'WITH' clause
                    # then the 'FROM' clause wil not be the appropriate
                    # place to get the table name from.
                    if ( exists $h->{from} ) {
                        my ( undef, $db_table ) = split /\s+/, $h->{from};
                        if ($db_table) {
                            $h->{db_table} = $db_table;
                        }
                    }
                }

                $field_count += scalar @{ $h->{fields} };
                $field_desc_count += $h->{field_desc_count};

                push @routes, $h;
            }
        }
    }

    my $route_count = scalar @routes;
    my $pct_route_desc = ($route_count) ? int( $route_desc_count * 100 / $route_count ) : 100;

    my $pct_field_desc = ($field_count) ? int( $field_desc_count * 100 / $field_count ) : 100;

    my %return = (
        'module_name'     => $module_name,
        'description'     => $description,
        'module_prefix'   => "/$module_prefix",
        'routes'          => \@routes,
        'pct_module_desc' => $pct_module_desc,
        'pct_route_desc'  => $pct_route_desc,
        'pct_field_desc'  => $pct_field_desc,
    );

    if ( ( config->{environment} eq 'development' ) || !$hide_doc ) {

        # Module documentation
        get "/$module_prefix(|/)" => sub {
            template 'module_index', \%return;
        };

        # Add the "auto-discovered" documentation routes
        foreach my $config (@routes) {

            my $show_doc = ( config->{environment} eq 'development' )
                || ( !exists $config->{hide_doc} );
            if ($show_doc) {
                my $doc_route = $config->{doc_route};
                warn "Setting up route: $doc_route\n";
                get "$doc_route" => sub { Tranquillus::Doc->do_doc($config) };
            }
        }
    }
    else {
        $return{hide_doc} = 1;
    }

    return \%return;
}

sub prime_config_fields {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $args, $pa ) = @_;

    my $field_desc_count = 0;

    foreach my $idx ( 0 .. @{ $args->{fields} } ) {
        my $field = @{ $args->{fields} }[$idx];

        # Check the description
        # Ensure that *some* description exists
        $field->{desc} ||= 'TODO';

        # Moderately bogus measure of how acceptable the field description is
        my $wc = () = $field->{desc} =~ m/([^\s]\s+[^\s])/g;
        $field_desc_count++
            if ( $wc > 3 );    # Because "ID for the widget" scores a 3

        # Check reference links
        if ( exists $field->{reference_href} ) {
            my $version = $args->{version};
            $field->{reference_href} =~ s/DOCROOT/$documentation_root/;
            $field->{reference_href} =~ s/VERSION/$version/;
        }

        # After this point, we only care about the fields that are
        # flagged as queryable
        next unless ( $field->{query_field} );

        my $name = $field->{name};

        if ( exists $pa->{$name} ) {
            $args->{fields}[$idx]{where_type} ||= $pa->{$name}{where_type};
            if ( ( exists $pa->{$name}{re} ) && $pa->{$name}{re} ) {
                $args->{fields}[$idx]{re} ||= $pa->{$field}{re};
            }
        }

        # Ensure that there is a regexp for untainting the data
        my $where_type = $field->{where_type} || 'text';

        if ( $where_type eq 'pos_int' ) {
            $args->{fields}[$idx]{re} ||= '[^0-9]';
        }
        elsif ( $where_type =~ m/_number$/ ) {

            # Need to beef this up.
            # - leading +/-
            # - only one decimal point (I18N, commas?)
            # - scientific notation (E+/-\d+) ??
            $args->{fields}[$idx]{re} ||= '[^0-9.]';
        }
        elsif ( $where_type =~ m/date$/ ) {

            # Dates get parsed separately as regexes won't cut it
            undef $args->{fields}[$idx]{re};
        }
        else {
            if ( $where_type =~ m/^(c|i)l_/ ) {
                $args->{fields}[$idx]{re} ||= '[^a-z0-9]+';
            }
            elsif ( $where_type =~ m/^(c|i)u_/ ) {
                $args->{fields}[$idx]{re} ||= '[^A-Z0-9]+';
            }
            else {
                $args->{fields}[$idx]{re} ||= '[^A-Za-z0-9]+';
            }
        }
    }

    my $field_count = scalar @{ $args->{fields} };

    $args->{field_desc_count} = $field_desc_count;
    $args->{pct_field_desc} = ($field_count) ? int( $field_desc_count * 100 / $field_count ) : 100;

    return $args;
}

sub global_query_parms {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $no_paging, $no_params ) = @_;
    my @parms;

    unless ($no_params) {
        @parms = (
            {
                name => 'format',
                desc =>
                    'The desired return format. Valid formats are: {json, jsonp, text, csv, xls, ods, and tab}. The default is json.',
                query_field => 1,
            },
            {
                name        => 'callback',
                desc        => 'The JSONP callback function name (Note that format needs to be "jsonp").',
                query_field => 1,
            },
            {
                name => 'fields',
                desc =>
                    'The comma-separated-list of the field names to return from the query. The default is to return all available fields.',
                query_field => 1,
            },
            {
                name => 'nullValue',
                desc =>
                    'Value to substitute in place of null values. The default is to return null values as "null" (per JSON.org).',
                query_field => 1,
            },
        );
    }

    if ( config->{environment} eq 'development' ) {
        my %h = (
            name        => 'showConfig',
            desc        => 'Development mode only. Returns the configuration used for the route.',
            query_field => 1,
        );
        push @parms, \%h;
    }

    # Paging
    unless ( $no_paging || $no_params ) {
        my %h = (
            name => 'limit',
            desc => 'The number of records to limit the result set to. Behaves like the SQL standard LIMIT clause.',
            query_field => 1,
        );
        push @parms, \%h;

        %h = (
            name => 'offset',
            desc =>
                'Used with Limit-- the record number to start retrieving from. Behaves like the SQL standard OFFSET clause.',
            query_field => 1,
        );
        push @parms, \%h;
    }

    return @parms;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

sub _slurp { local ( *ARGV, $/ ); @ARGV = shift; <> }

true;
