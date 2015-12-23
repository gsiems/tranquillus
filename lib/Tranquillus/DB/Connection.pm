package Tranquillus::DB::Connection;
use Dancer2 appname => 'Tranquillus';

use DBIx::Connector;
use Tranquillus::Util;
use Data::Dumper;

# http://search.cpan.org/~dwheeler/DBIx-Connector-0.53/lib/DBIx/Connector.pm

my %db_connections;

sub get_engine {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($database) = @_;

    $database ||= 'default';

    my $db_config = config->{Databases};
    my ( $scheme, $driver, $attr_string, $attr_hash, $driver_dsn );

    if ( exists $db_config->{$database} ) {
        my $dsn = $db_config->{$database}{dsn};
        if ($dsn) {
            ( $scheme, $driver, $attr_string, $attr_hash, $driver_dsn ) = DBI->parse_dsn($dsn);
        }
    }
    return $driver;
}

#sub get_sth {
#    my $self ;
#    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
#
#}

sub get_dbh {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($database) = @_;

    $database ||= 'default';

    # Do we already have a connection?
    my $conn = $db_connections{$database}{conn} || undef;

    if ($conn) {

        # Do we need to do anything else?
        # Such as checking the last ping/status of the DB connection?
        # How do we deal with databases that go down for a while before coming back?
        # $db_connections{$database}{last_status} -- result of last status check
        # $db_connections{$database}{last_status_change} -- tmsp
        # $db_connections{$database}{last_check} -- tmsp
        # $db_connections{$database}{next_check} -- tmsp

        return $conn->dbh;
    }
    else {
        my $db_config = config->{Databases};

        # Ensure that a configuration exists for the requested database
        unless ( exists $db_config->{$database} ) {
            Tranquillus::Util->return_error( 'NO_DB_CONF', "[ $database ]" );
        }

        my $dsn      = $db_config->{$database}{dsn};
        my $username = $db_config->{$database}{username};
        my $password = $db_config->{$database}{password};

        # Not currently using SQLite, but that won't need a usename/password...

        if ( exists $db_config->{$database}{dbi_parmas} ) {
            $conn = DBIx::Connector->new( $dsn, $username, $password, $db_config->{$database}{dbi_parmas} );
        }
        else {
            $conn = DBIx::Connector->new(
                $dsn,
                $username,
                $password,
                {
                    RaiseError => 1,
                    AutoCommit => 1,
                }
            );
        }

        # Error?
        unless ( $conn && $conn->dbh ) {
            Tranquillus::Util->return_error('DB_DOWN');
        }

        #
        if ( exists $db_config->{$database}{on_connect_do} ) {
            $conn->dbh->do($_) for @{ $db_config->{$database}{on_connect_do} };
        }

        $db_connections{$database}{conn} = $conn;

        return $conn->dbh;
    }
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
