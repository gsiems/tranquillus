package Tranquillus::Doc;
use Dancer2 appname => 'Tranquillus';
use Data::Dumper;

sub do_doc {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;

    if ( config->{environment} eq 'development' && exists params->{showConfig} ) {

        my %h;
        my %t;

        # Strip out any non-valid config file elements
        # TODO: Fill out the remainder of the list
        foreach my $key (
            qw(
            custom_data
            database
            db_engine
            desc
            examples
            fields
            from
            link
            no_global_parms
            no_paging
            order_by
            parms_optional
            use_streaming
            version
            with
            )
            )
        {

            if ( exists $args->{$key} ) {
                $t{$key} = $args->{$key};
            }
        }

        $h{route_config} = to_json( \%t, { ascii => 1, pretty => 1 } );

        $h{$_} = $args->{$_} for (qw(module_prefix module_name doc_route data_route pct_route_desc pct_field_desc ));

        template 'route_config', \%h;

    }
    else {
        my %h = %{$args};

        my @query_fields;
        my @result_fields;

        foreach my $field ( @{ $args->{fields} } ) {
            if ( exists $field->{query_field} && $field->{query_field} ) {
                push @query_fields, $field;
            }
            if ( exists $field->{db_column} && $field->{db_column} ) {
                push @result_fields, $field;
            }
        }

        # Are there query fields:
        if (@query_fields) {

            # Are the query fields optional or required?
            my $parms_optional = $args->{parms_optional}
                || ( scalar @query_fields > 1 );

            foreach my $field (@query_fields) {
                if ( $field->{query_field} > 1 ) {
                    $field->{required} = 'Yes';
                }
                elsif ( !$parms_optional ) {
                    $field->{required} = 'Yes';
                }
            }
            $h{query_fields} = \@query_fields;
        }

        # Are there result fields:
        if (@result_fields) {
            $h{result_fields} = \@result_fields;
        }

        $h{environment} = config->{environment};

        template 'route_doc', \%h;
    }
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
