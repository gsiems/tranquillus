package Tranquillus::Data;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Util;

sub return_custom_data {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $rt_config, $result ) = @_;

    my $deprecation_policy = Tranquillus::Util->deprecation_policy($rt_config);
    if ( $deprecation_policy->{status} == 2 ) {

        # TODO: redirect or error of some form? 404? Is there a best
        # practice for RESTful?
        redirect '/';
    }

    #    $result->{deprecation_policy} = $deprecation_policy;
    $result->{format}     = $rt_config->{format};
    $result->{deprecated} = $rt_config->{deprecated};

    if ( $rt_config->{deprecated_by} ) {
        $result->{deprecated_by} = $rt_config->{deprecated_by};
    }
    if ( $rt_config->{deprecated_until} ) {
        $result->{deprecated_until} = $rt_config->{deprecated_until};
    }

    unless ( exists $result->{invalid_parms} ) {
        $result->{invalid_parms} = Tranquillus::Util->get_invalid_parms($rt_config);
    }

    return_result($result);
}

sub return_result {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($result) = @_;

    my %return;

    $return{data} = $result->{data};
    $return{data} ||= ();
    my @column_names = ( exists $result->{column_names} ) ? @{ $result->{column_names} } : ();
    if ( !@column_names && exists $result->{data} && @{ $result->{data} } ) {
        @column_names = sort keys %{ @{ $result->{data} }[0] };
    }

    $return{column_names} = \@column_names;
    $return{deprecated} = ( $result->{deprecation_policy}{status} ) ? 'true' : 'false';
    #    $return{deprecation_policy} = $result->{deprecation_policy};

    if ( config->{environment} eq 'development' ) {
        $return{invalid_parms} = $result->{invalid_parms};
        $return{valid_parms}   = $result->{valid_parms};
        $return{query}         = $result->{query};
        $return{vars}          = $result->{vars};
    }

    if ( $result->{deprecated_by} ) {
        $return{deprecated_by} = $result->{deprecated_by};
    }
    if ( $result->{deprecated_until} ) {
        $return{deprecated_until} = $result->{deprecated_until};
    }

    $return{uri} = request->path;
    if ( exists $return{data} && defined $return{data} ) {
        $return{recordCount} = scalar @{ $return{data} } || 0;
    }

    my $return_text = '';

    my ( $format, $file_name, $disposition, @headers );
    ( $format, $file_name, $disposition, @headers ) = Tranquillus::Util->header_info( $result->{format} );

    if ( $result->{errors} ) {

        if ( ref( $result->{errors} ) eq 'ARRAY' ) {
            $return{errors} = $result->{errors};
        }
        else {
            push @{ $return{errors} }, $result->{errors};
        }

        header( 'Content-Type' => 'text/html' );

        $return_text =
              "<html><head></head><body><pre>\n"
            . to_json( \%return, { ascii => 1, pretty => 1 } )
            . "\n</pre></body></html>\n";
    }
    else {

        for ( my $i = 0 ; $i < $#headers ; $i += 2 ) {
            header( $headers[$i] => $headers[ $i + 1 ] );
        }

        # [JSON AS] TEXT
        if ( $format eq 'text' ) {
            $return_text =
                  "<html><head></head><body><pre>\n"
                . to_json( \%return, { ascii => 1, pretty => 1 } )
                . "\n</pre></body></html>\n";
        }

        # JSON
        elsif ( $format eq 'json' ) {
            $return_text = to_json( \%return, { ascii => 1 } );
        }

        # JSON-P
        elsif ( $format eq 'jsonp' ) {
            my $callback = Tranquillus::Util->requested_callback();
            $return_text = $callback . "(" . to_json( \%return, { ascii => 1 } ) . ");";
        }
        elsif ($format eq 'tab'
            || $format eq 'csv'
            || $format eq 'ods'
            || $format eq 'xls' )
        {
            header( 'Content-Disposition' => $disposition );

            if (@column_names) {
                $return_text = Tranquillus::Util->a2delimited( $format, @column_names );

                foreach my $row ( @{ $result->{data} } ) {
                    my @a =
                        map { ( defined $row->{$_} ) ? $row->{$_} : '' } @column_names;
                    $return_text .= Tranquillus::Util->a2delimited( $format, @a );
                }
            }
        }
        else {
            $return_text = to_json( \%return, { ascii => 1, pretty => 1 } );
        }
    }

    return $return_text;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
