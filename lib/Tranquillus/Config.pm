package Tranquillus::Config;

use Dancer2 appname => 'Tranquillus';
use JSON ();
use Tranquillus::Doc;
#use Data::Dumper;

use POSIX qw(strftime);

my $data_root = ( exists config->{data_root} ) ? config->{data_root} : '/api/vVERSION';
my $documentation_root =
    ( exists config->{documentation_root} )
    ? config->{documentation_root}
    : '/api/doc/vVERSION';
my $config_root =
    ( exists config->{config_root} )
    ? config->{config_root}
    : '/api/config/vVERSION';

sub read_configs {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = (@_);

    my $config_dir = $args->{config_dir};
    # Ensure that there is *something* for the description
    my $description = $args->{description} || 'TODO';
    my $hide_doc    = $args->{hide_doc}    || 0;
    my $module_name = $args->{module_name};
    my $module_url_token = $args->{module_url_token};
    my $parm_parse_rules = $args->{parm_parse_rules};

    # Use the length of the descriptions of modules, routes and fields
    # aid to encouraging some minimally viable (or much better) level of
    # documentation. While minimum length is a lousy metric it is quick,
    # easy, and should help the documenters find the routes that need
    # help in that area, maybe.

    # Moderately bogus measure of how acceptable the module description is
    my $wc = () = $description =~ m/([^\s]\s+[^\s])/g;
    my $module_doc_score = ( $wc >= 7 ) ? 100 : int( $wc * 100 / 7 );

    my $route_doc_count = 0;
    my $field_doc_count = 0;
    my $field_count     = 0;

    my @routes;

    if ( -d $config_dir ) {
        opendir( my $dh, $config_dir );
        if ($dh) {
            my @config_files =
                grep { -f $_ }
                grep { $_ =~ m/\.(json|yml|yaml)$/i }
                map  { "$config_dir/$_" } readdir($dh);
            closedir $dh;

            foreach my $file (@config_files) {
                my $rt_config = _slurp($file);
                my $h;
                if ( $file =~ m/\.json$/i ) {
                    $h = JSON::from_json( $rt_config, { utf8 => 1 } );
                }
                else {
                    $h = YAML::Load( decode( 'UTF-8', $rt_config ) );
                }

                # Ensure that there is a version number for the route
                $h->{version} ||= 1;

                # Ensure that *some* description exists
                $h->{desc} ||= 'TODO';

                # Moderately bogus measure of how acceptable the
                # route description is
                my $wc = () = $h->{desc} =~ m/([^\s]\s+[^\s])/g;

                # Because "Valid values for x" == 3
                my $route_doc_score = ( $wc >= 3 ) ? 100 : int( $wc * 100 / 3 );
                $h->{route_doc_score} = $route_doc_score;

                if ( $wc >= 3 ) {
                    $route_doc_count++;
                }

                #
                $h->{module_name}      = $module_name;
                $h->{module_url_token} = $module_url_token;
                $h->{database} ||= 'default';

                my $doc_route = join '/', $documentation_root, $module_url_token, $h->{link};
                $doc_route =~ s/VERSION/$h->{version}/;
                $h->{doc_route} = $doc_route;

                my $data_route = join '/', $data_root, $module_url_token, $h->{link};
                $data_route =~ s/VERSION/$h->{version}/;
                $h->{data_route} = $data_route;

                #
                $h = prime_config_fields( $h, $parm_parse_rules );

                my $no_paging = ( exists $h->{no_paging} ) ? $h->{no_paging} : 0;
                my $no_params = ( exists $h->{no_params} ) ? $h->{no_params} : 0;

                my @gp = global_query_parms( $no_paging, $no_params );

                if (@gp) {
                    $h->{format_fields} = \@gp;
                }

                if ( config->{show_config} ) {
                    my $config_route = join '/', $config_root, $module_url_token, $h->{link};
                    $config_route =~ s/VERSION/$h->{version}/;
                    $h->{config_route} = $config_route;
                }

                if ( config->{show_developer_doc} ) {
                    # TODO: If the configuration uses a 'WITH' clause
                    # then the 'FROM' clause will not be the appropriate
                    # place to get the table name from.
                    if ( exists $h->{from} ) {
                        my ( undef, $db_table ) = split /\s+/, $h->{from};
                        if ($db_table) {
                            $h->{db_table} = $db_table;
                        }
                    }
                }

                my $show_doc = ( config->{show_hidden_doc} && config->{show_hidden_doc} )
                    || ( !exists $h->{hide_doc} );
                $h->{show_doc} = $show_doc;

                $field_count += scalar @{ $h->{fields} };
                $field_doc_count += $h->{field_doc_count};

                $h->{raw_config} = $rt_config;

                unshift @routes, $h;
            }
        }
    }

    my $route_count     = scalar @routes;
    my $route_doc_score = ($route_count) ? int( $route_doc_count * 100 / $route_count ) : 100;
    my $field_doc_score = ($field_count) ? int( $field_doc_count * 100 / $field_count ) : 100;

    @routes = sort { $a->{link} cmp $b->{link} } @routes;

    my %return = (
        'module_name'      => $module_name,
        'description'      => $description,
        'module_url_token' => $module_url_token,
        'routes'           => \@routes,
        'module_doc_score' => $module_doc_score,
        'route_doc_score'  => $route_doc_score,
        'route_doc_count'  => $route_doc_count,
        'route_count'      => $route_count,
        'field_doc_score'  => $field_doc_score,
        'field_doc_count'  => $field_doc_count,
        'field_count'      => $field_count,
    );

    if ( ( config->{show_hidden_doc} && config->{show_hidden_doc} ) || !$hide_doc ) {

        #my $dev_doc = to_json( \%return, { ascii => 1, pretty => 1 } );
        #$return{dev_doc} = $dev_doc;

        # Module documentation
        get "/$module_url_token(|/)" => sub {
            template 'module_index', \%return;
        };

        # Add the "auto-discovered" documentation routes
        foreach my $rt_config (@routes) {

            my $show_doc = ( config->{show_hidden_doc} && config->{show_hidden_doc} )
                || ( !exists $rt_config->{hide_doc} );
            if ($show_doc) {
                my $doc_route = $rt_config->{doc_route};
                my $now = strftime "%Y%m%d-%H:%M:%S", localtime;

                warn "[$now] Setting up route: $doc_route\n";
                get "$doc_route" => sub { Tranquillus::Doc->do_doc($rt_config) };
            }

            if ( config->{show_config} ) {
                my $config_route = $rt_config->{config_route};
                get "$config_route" => sub { Tranquillus::Doc->do_config($rt_config) };
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

    my $field_doc_count = 0;    # Count of fields with *long enough* descriptions

    foreach my $idx ( 0 .. @{ $args->{fields} } ) {
        my $field = @{ $args->{fields} }[$idx];

        # Check the description
        # Ensure that *some* description exists
        $field->{desc} ||= 'TODO';

        # Moderately bogus measure of how acceptable the field description is
        my $wc = () = $field->{desc} =~ m/([^\s]\s+[^\s])/g;

        $field->{field_doc_score} = ( $wc >= 3 ) ? 100 : 0;

        if ( $wc >= 3 ) {

            # Because "ID for the widget" scores a 3, and one hopes
            # there is more to the description than that.
            $field_doc_count++;
        }

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

        unless ( $args->{fields}[$idx]{where_type} ) {
            $args->{fields}[$idx]{where_type} = $pa->{$name}{where_type};
        }
        unless ( $args->{fields}[$idx]{re} ) {
            $args->{fields}[$idx]{re} = $pa->{$name}{re};
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
                $args->{fields}[$idx]{re}         ||= '[^A-Za-z0-9]+';
                $args->{fields}[$idx]{where_type} ||= 'text';
            }
        }
    }

    my $field_count = scalar @{ $args->{fields} };

    if ( exists $args->{no_global_parms} && $args->{no_global_parms} ) {
        $args->{no_params} = 1;
    }

    $args->{field_doc_count} = $field_doc_count;
    $args->{field_doc_score} = ($field_count) ? int( $field_doc_count * 100 / $field_count ) : 100;

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

    # Paging
    unless ( $no_paging || $no_params ) {

        push @parms,
            {
            name => 'limit',
            desc => 'The number of records to limit the result set to. Behaves like the SQL standard LIMIT clause.',
            query_field => 1,
            };

        push @parms,
            {
            name => 'offset',
            desc =>
                'Used with Limit-- the record number to start retrieving from. Behaves like the SQL standard OFFSET clause.',
            query_field => 1,
            };
    }

    return @parms;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

sub _slurp { local ( *ARGV, $/ ); @ARGV = shift; <> }

true;
