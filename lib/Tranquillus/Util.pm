package Tranquillus::Util;
use Dancer2 appname => 'Tranquillus';

use JSON ();
use POSIX qw(strftime);

our %content_types = (
    'xls' => {
        'Content-Type' => 'application/vnd.ms-excel',
        'extension'    => '.xls',
    },
    'ods' => {
        'Content-Type' => 'application/vnd.oasis.opendocument.spreadsheet',
        'extension'    => '.ods',
    },
    'csv' => {
        'Content-Type' => 'text',
        'extension'    => '.csv',
    },
    'tab' => {
        'Content-Type' => 'text',
        'extension'    => '.tab',
    },
    'text' => {
        'Content-Type' => 'text/html; charset=UTF-8',
        'extension'    => '.txt',
        'head'         => "<html><head></head><body><pre>\n",
        'tail'         => "\n</pre></body></html>\n",
    },
    'json' => {
        'Content-Type' => 'application/json; charset=UTF-8',
        'extension'    => '.json',
    },
    'jsonp' => {
        'Content-Type' => 'application/json; charset=UTF-8',
        'extension'    => '.json',
    },
);

my %error_codes = (
    'BAD_QUERY' => {
        'text' => 'Service Unavailable: Bad query.',
        'code' => 503,
    },
    'DB_DOWN' => {
        'text' => 'Service Unavailable: Database is down for maintenance.',
        'code' => 503,
    },
    'NO_DB_CONF' => {
        'text' => 'Service Unavailable: An attempt was made to connect to an unconfigured database.',
        'code' => 503,
    },
    'BAD_DB_CONF' => {
        'text' => 'Service Unavailable: An attempt was made to connect to a misconfigured database.',
        'code' => 503,
    },
    'NOT_FOUND' => {
        'text' => 'Document cannot be found.',
        'code' => 404,
    },
);

sub return_error {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $label, @information ) = @_;

    my ( $text, $code );
    if ( exists $error_codes{$label} ) {
        $text = $error_codes{$label}{text};
        $code = $error_codes{$label}{code};
    }
    else {
        $text = 'There was an error.';
        $code = 503;
    }

    if (@information) {
        $text .= join( ' ', @information );
    }

    send_error( $text, $code );
}

sub a2delimited {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $format, @ary ) = @_;

    if ( $format eq 'tab' ) {    # Convert an array to a line of tab-separated-values
        foreach (@ary) {
            $_ =~ s/\t/\\t/g;
        }
        return join( "\t", @ary ) . "\r\n";
    }
    else {                       # Convert an array to csv
        foreach (@ary) {
            if ( $_ =~ m/[,"]/ ) {
                $_ =~ s/"/\"/g;
                $_ = '"' . $_ . '"';
            }
        }
        return join( ",", @ary ) . "\r\n";
    }
}

sub deprecation_policy {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($args) = @_;
    my %policy;

    $policy{status} = ( exists $args->{deprecated} && $args->{deprecated} ) ? 1 : 0;

    if ( $policy{status} ) {
        my $deprecated_by = $args->{deprecated_by} || undef;
        if ($deprecated_by) {

            # TODO: Ensure that the deprecated_by path
            # $deprecated_by =~ s|^/api/v|/api/doc/v|;

            $policy{deprecated_by} = $deprecated_by;
        }

        my $deprecated_until = $args->{deprecated_until} || undef;
        if ($deprecated_until) {
            my ( $year, $month, $day ) = split '-', $deprecated_until;
            my $tz = strftime "%Z", localtime;
            my $depdate = DateTime->new(
                year      => $year,
                month     => $month,
                day       => $day,
                time_zone => $tz,
            );

            $policy{status}           = ( $depdate->epoch() > time() ) ? 1 : 2;
            $policy{deprecated_until} = $deprecated_until;
            $policy{epoch}            = $depdate->epoch();
            $policy{now}              = time();
        }
    }

    return \%policy;
}

sub cache_control {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    if ( config->{environment} eq 'production' ) {

        # TODO: Allow for routes to set their own cache control rules.
        # Also, allow for a global value to be set in the application
        # configuration.
        my $max_age = 30 * 60;
        return ( 'Cache-Control', 'max-age = ' . $max_age );
    }
    else {
        return ( 'Cache-Control', 'no-store, no-cache, must-revalidate' );
    }
}

sub content_info {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $format, $base_name ) = @_;
    $base_name ||= 'data';
    $base_name =~ s/[^A-Z0-9.-]/_/ig;

    $format ||= 'text';

    # TODO: Should we also make the charset for the content type a
    # configuration file item?
    my $content_type = $content_types{$format}{'Content-Type'} || $content_types{text}{'Content-Type'};
    my $file_name    = $base_name . $content_types{$format}{'extension'};
    my $disposition  = 'attachment; filename="' . $file_name . '"';

    return ( $content_type, $file_name, $disposition );
}

sub null_value {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($default_null) = @_;

    # Allow the user to override the default undefined => "null" behavior
    my $null_value = ( defined $default_null ) ? $default_null : 'null';

    $null_value =~ s/[^a-z0-9 _-]//ig;    # just say no to XSS

    return $null_value;
}

sub is_valid_response_format {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($format) = @_;

    return ( exists $content_types{ lc $format } );
}

sub response_format {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($format) = @_;

    my $return;
    if ( $format && exists $content_types{ lc $format } ) {
        $return = lc $format;
    }
    elsif ( exists params->{'format'} && exists $content_types{ lc params->{'format'} } ) {
        $return = lc params->{'format'};
    }
    $return ||= 'text';

    return $return;
}

sub requested_callback {
    my $callback =
        ( exists params->{'callback'} && params->{'callback'} )
        ? params->{'callback'}
        : 'callback';

    $callback =~ s/[^A-Za-z0-9_]/_/g;    # just say no to XSS
    return $callback;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
