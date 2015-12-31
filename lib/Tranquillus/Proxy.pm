package Tranquillus::Proxy;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Util;

sub proxy_request {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $proxy_route, $file_name ) = @_;

    unless ($proxy_route) {
        Tranquillus::Util->return_error('BAD_QUERY');
    }

    my $cb = sub {
        my $respond = $Dancer2::Core::Route::RESPONDER;
        require LWP;
        my $ua = LWP::UserAgent->new;
        my $writer;
        my %m;

        $ua->get(
            $proxy_route,
            ':content_cb' => sub {
                my ( $data, $response, $protocol ) = @_;

                if ( not $writer ) {
                    my $h = $response->headers;

                    my @ary = ( 'Content-Length', 'Content-Type', 'Last-Modified', 'Content-Disposition' );

                    foreach my $key (@ary) {
                        if ( $h->header($key) ) {
                            $m{$key} = $h->header($key);
                        }
                    }
                    if ($file_name) {
                        $m{'Content-Disposition'} ||= 'attachment; filename="' . $file_name . '"';
                    }
                    $writer = $respond->( [ $response->code, [%m] ] );
                }
                $writer->write($data);
            },
        );
        unless ( exists $m{'Content-Length'} ) {
            # How to indicate EOF???
            # Transfer-Encoding: chunked???
            #$writer->write(chr(0) . chr(10) . chr(13));
            #$writer->write( chr(10) . chr(13));
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

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
