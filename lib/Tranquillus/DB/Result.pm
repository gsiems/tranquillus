package Tranquillus::DB::Result;
use Dancer2 appname => 'Tranquillus';

use DateTime;
use Tranquillus::Util;
use Tranquillus::DB::Connection;
use Data::Dumper;

sub return_query_result {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($query) = @_;

    if ( exists $query->{format} ) {
        unless ( Tranquillus::Util->is_valid_response_format( $query->{format} ) ) {
            $query->{errors} .= "An invalid return format was specified.";
        }
    }
    $query->{format} = Tranquillus::Util->response_format( $query->{format} );

    # TODO: cleanup/streamline the "config" flow

    # TODO: determine whether or not to use streaming to return the
    # query results.

    #stream_result($query);
    standard_result($query);

}

sub standard_result {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;

    my %return;
    my @data;
    my @column_names = @{ $args->{column_names} };

    my $dbh = Tranquillus::DB::Connection->get_dbh( $args->{database} );

    if ($dbh) {

        my $sth = $dbh->prepare( $args->{query} );
        unless ($sth) {
            if ( config->{environment} eq 'development' ) {
                Tranquillus::Util->return_error( 'BAD_QUERY', $dbh->errstr );
            }
            else {
                Tranquillus::Util->return_error('BAD_QUERY');
            }
        }

        my @vars = ( exists $args->{vars} ) ? @{ $args->{vars} } : ();

        if (@vars) {
            $sth->execute(@vars);
        }
        else {
            $sth->execute();
        }

        my $null_value = Tranquillus::Util->null_value( $args->{nullValue} );

        foreach my $row ( @{ $sth->fetchall_arrayref() } ) {
            my %h;
            foreach ( 0 .. $#column_names ) {
                $h{ $column_names[$_] } = ( defined $row->[$_] ) ? $row->[$_] : $null_value;
            }
            push @data, \%h;
        }
    }

    # TODO: What was I thinking?
    foreach my $key ( keys %{$args} ) {
        $return{$key} = $args->{$key}
            unless ( $key =~
            m/^(vars|params|format|valid_parms|invalid_params|deprecated|parms_optional|query|loop_query|loop_args)$/ );
    }

    $return{data} = \@data;

    $return{deprecated} = ( $args->{deprecated}{status} ) ? 'true' : 'false';

    if ( $args->{deprecated_by} ) {
        $return{deprecated_by} = $args->{deprecated_by};
    }
    if ( $args->{deprecated_until} ) {
        $return{deprecated_until} = $args->{deprecated_until};
    }

    $return{uri} = request->path;
    if ( exists $return{data} ) {
        $return{recordCount} = scalar @{ $return{data} };
    }

    my $return_text = '';

    my ( $format, $file_name, $disposition, @headers );
    ( $format, $file_name, $disposition, @headers ) = Tranquillus::Util->header_info( $args->{format} );

    if ( $args->{errors} ) {
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

                foreach my $row (@data) {
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

    # Not sure if this helps reduce memory usage or not...
    delete $args->{$_} for ( keys %{$args} );
    undef $args;
    delete $return{$_} for ( keys %return );
    undef %return;

    return $return_text;
}

sub stream_result {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;

    # TODO: Determine if psgi.streaming is supported and throw error if not
    my $dbh = Tranquillus::DB::Connection->get_dbh( $args->{database} );

    if ($dbh) {

        my $sth = $dbh->prepare( $args->{query} );
        unless ($sth) {
            Tranquillus::Util->return_error('BAD_QUERY');
        }

        my @vars = ( exists $args->{vars} ) ? @{ $args->{vars} } : ();
        $sth->execute(@vars);

        my ( $format, $file_name, $disposition, @header ) = Tranquillus::Util->header_info( $args->{format} );
        my @column_names = @{ $args->{column_names} };

        # Default null value
        my $null_value = Tranquillus::Util->null_value( $args->{nullValue} );

        if (   $format eq 'tab'
            || $format eq 'csv'
            || $format eq 'ods'
            || $format eq 'xls' )
        {

            my $cb = sub {
                my $respond = $Dancer2::Core::Route::RESPONDER;
                my $writer = $respond->( [ 206, [ @header, 'Content-Disposition' => $disposition ] ] );

                $writer->write( Tranquillus::Util->a2delimited( $format, @column_names ) );

                while (
                    my @data =
                    map { ( defined $_ ) ? $_ : $null_value } $sth->fetchrow_array()
                    )
                {
                    $writer->write( Tranquillus::Util->a2delimited( $format, @data ) );
                }

                $writer->close;
            };

            my $response = Dancer2::Core::Response::Delayed->new(

                #            error_cb => sub { $weak_self->logger_engine->log( warning => @_ ) },
                cb       => $cb,
                request  => $Dancer2::Core::Route::REQUEST,
                response => $Dancer2::Core::Route::RESPONSE,
            );
            return $response;
        }

        elsif ( $format eq 'text' || $format eq 'json' || $format eq 'jsonp' ) {
            my ( $jhead, $jtail, $json_pretty, $rec_delimiter ) = get_json_wrapper( $format, $args );

            my $cb = sub {
                my $first   = 1;
                my $respond = $Dancer2::Core::Route::RESPONDER;
                my $writer  = $respond->( [ 206, [@header] ] );
                $writer->write($jhead);
                my $recordcount = 0;
                while (
                    my @data =
                    map { ( defined $_ ) ? $_ : $null_value } $sth->fetchrow_array()
                    )
                {
                    my %h =
                        map { $column_names[$_] => ( defined $data[$_] ) ? $data[$_] : $null_value }
                        ( 0 .. $#column_names );
                    my $rec = ($recordcount) ? $rec_delimiter : '';
                    $rec .= to_json( \%h, { ascii => 1, pretty => $json_pretty } );
                    $rec =~ s/\n$//;
                    $writer->write($rec);
                    $recordcount++;
                }

                $jtail =~ s/REC_COUNT/$recordcount/;
                $writer->write( $jtail . "\n" );

                $writer->close;
            };

            my $response = Dancer2::Core::Response::Delayed->new(

                #            error_cb => sub { $weak_self->logger_engine->log( warning => @_ ) },
                cb       => $cb,
                request  => $Dancer2::Core::Route::REQUEST,
                response => $Dancer2::Core::Route::RESPONSE,
            );
            return $response;
        }
    }
}

sub get_jhead {
    my ( $format, $args ) = @_;

    my $verbose = 1;

    my %fore = (
        format     => $format,
        uri        => request->path,
        deprecated => ( $args->{deprecated}{status} ) ? 'true' : 'false',
    );

    if ( $args->{deprecated_by} ) {
        $fore{deprecated_by} = $args->{deprecated_by};
    }
    if ( $args->{deprecated_until} ) {
        $fore{deprecated_until} = $args->{deprecated_until};
    }

    my $jhead = to_json( \%fore, { ascii => 1, pretty => 1 } );
    $jhead =~ s/\n[}][\s\n]*$//;
    $jhead .= qq|,\n   "data" : [\n|;

    if ( $format eq 'text' ) {
        $jhead = "<html><head></head><body><pre>\n" . $jhead;
    }
    elsif ( $format eq 'jsonp' ) {
        my $callback = Tranquillus::Util->requested_callback();

        $jhead = $callback . "(" . $jhead;
        $jhead =~ s/\n\s*/ /;
    }
    else {
        $jhead =~ s/\n\s*/ /;
    }

    return $jhead;
}

sub get_jtail {
    my ($format) = @_;

    my $jtail = qq|
    ],
    "recordCount" : REC_COUNT
}
|;

    if ( $format eq 'text' ) {
        $jtail .= "\n</pre></body></html>\n";
    }
    elsif ( $format eq 'jsonp' ) {
        $jtail .= ");";
        $jtail =~ s/\n\s*/ /;
    }
    else {
        $jtail =~ s/\n\s*/ /;
    }
    return $jtail;
}

sub get_json_wrapper {
    my ( $format, $args ) = @_;

    my $jhead = get_jhead( $format, $args );
    my $jtail = get_jtail($format);

    if ( $format eq 'text' ) {
        return ( $jhead, $jtail, 1, ",\n" );
    }

    return ( $jhead, $jtail, 0, ", " );
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
