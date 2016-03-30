package Tranquillus::DB::Result;
use Dancer2 appname => 'Tranquillus';

use DateTime;
use Tranquillus::Util;
use Tranquillus::DB::Connection;
use Tranquillus::Data;
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

    # Determine whether or not to use streaming to return the
    # query results.
    if ( $query->{use_streaming} ) {
        stream_result($query);
    }
    elsif ( exists $query->{vars} && ref( $query->{vars} ) eq 'ARRAY' && ref( @{ $query->{vars} }[0] ) eq 'ARRAY' ) {
        stream_result($query);
    }
    else {
        # Store-and-Forward
        standard_result($query);
    }
}

sub standard_result {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($query) = @_;

    my @data;
    my @column_names = @{ $query->{column_names} };

    my $dbh = Tranquillus::DB::Connection->get_dbh( $query->{database} );

    if ($dbh) {

        my $sth = $dbh->prepare( $query->{query} );
        unless ($sth) {
            if ( exists config->{show_errors} && config->{show_errors} ) {
                Tranquillus::Util->return_error( 'BAD_QUERY', $dbh->errstr );
            }
            else {
                Tranquillus::Util->return_error('BAD_QUERY');
            }
        }

        my @vars = ( exists $query->{vars} ) ? @{ $query->{vars} } : ();

        if (@vars) {
            $sth->execute(@vars);
        }
        else {
            $sth->execute();
        }

        my $null_value = Tranquillus::Util->null_value( $query->{nullValue} );

        foreach my $row ( @{ $sth->fetchall_arrayref() } ) {
            my %h;
            foreach ( 0 .. $#column_names ) {
                $h{ $column_names[$_] } = ( defined $row->[$_] ) ? $row->[$_] : $null_value;
            }
            push @data, \%h;
        }
    }

    my %result = (
        column_names     => $query->{column_names},
        deprecated_by    => $query->{deprecated_by},
        deprecated       => $query->{deprecated},
        deprecated_until => $query->{deprecated_until},
        format           => $query->{format},
        invalid_parms    => $query->{invalid_parms},
        query            => $query->{query},
        valid_parms      => $query->{valid_parms},
        vars             => $query->{vars},
    );

    $result{data} = \@data;

    my $return = Tranquillus::Data->return_result( \%result );
    foreach ( @{ $result{data} } ) {
        $_ = undef;
    }
    delete $result{$_} for ( keys %result );
    undef %result;

    return $return;
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

        # If an array of arrays has been supplied for the vars then we
        # want to loop through the outer array and perform a select
        # using each inner array as the query parms. If only a simple
        # array has been passed then only do the one query with the
        # @vars as the query parms.

        my @vars = ( exists $args->{vars} ) ? @{ $args->{vars} } : ();
        my $use_loop = ( $vars[0] && ref( $vars[0] ) && ref( $vars[0] ) eq 'ARRAY' ) ? 1 : 0;

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
                my $writer  = $respond->(
                    [ 206, [ @header, 'Transfer-Encoding' => 'chunked', 'Content-Disposition' => $disposition ] ] );

                $writer->write( Tranquillus::Util->a2delimited( $format, @column_names ) );

                if ($use_loop) {
                    foreach my $loop_vars (@vars) {
                        $sth->execute( @{$loop_vars} );
                        while (
                            my @data =
                            map { ( defined $_ ) ? $_ : $null_value } $sth->fetchrow_array()
                            )
                        {
                            $writer->write( Tranquillus::Util->a2delimited( $format, @data ) );
                            foreach (@data) {
                                $_ = undef;
                            }
                            undef @data;
                        }
                    }
                }
                else {
                    $sth->execute(@vars);
                    while (
                        my @data =
                        map { ( defined $_ ) ? $_ : $null_value } $sth->fetchrow_array()
                        )
                    {
                        $writer->write( Tranquillus::Util->a2delimited( $format, @data ) );
                        foreach (@data) {
                            $_ = undef;
                        }
                        undef @data;
                    }
                }

                $writer->write(undef);
                $writer->write("\r\n");
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
                my $writer  = $respond->( [ 206, [ @header, 'Transfer-Encoding' => 'chunked' ] ] );
                $writer->write($jhead);
                my $recordcount = 0;

                if ($use_loop) {
                    foreach my $loop_vars (@vars) {
                        $sth->execute( @{$loop_vars} );
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

                            foreach (@data) {
                                $_ = undef;
                            }
                            undef @data;
                            foreach ( keys %h ) {
                                delete $h{$_};
                            }
                            undef %h;
                            $rec = undef;

                            $recordcount++;
                        }
                    }
                }
                else {
                    $sth->execute(@vars);
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

                        foreach (@data) {
                            $_ = undef;
                        }
                        undef @data;
                        foreach ( keys %h ) {
                            delete $h{$_};
                        }
                        undef %h;
                        $rec = undef;

                        $recordcount++;
                    }
                }

                $jtail =~ s/REC_COUNT/$recordcount/;
                $writer->write($jtail);
                $writer->write(undef);
                $writer->write("\r\n");

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

    if ( config->{show_developer_doc} ) {
        $fore{invalid_parms} = $args->{invalid_parms};
        $fore{valid_parms}   = $args->{valid_parms};
        $fore{query}         = $args->{query};
        $fore{vars}          = $args->{vars};
    }

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
