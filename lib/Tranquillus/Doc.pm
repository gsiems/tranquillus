package Tranquillus::Doc;
use Dancer2 appname => 'Tranquillus';

sub do_doc {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;

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

    template 'route_doc', \%h;
}

sub do_config {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;

    if ( config->{show_config} ) {

        my %h;
        $h{route_config} = $args->{raw_config};

        $h{$_} = $args->{$_}
            for (qw(module_url_token module_name doc_route data_route config_route route_doc_score field_doc_score ));

        template 'route_config', \%h;
    }
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
