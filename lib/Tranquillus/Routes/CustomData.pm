package Tranquillus::Routes::CustomData;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Config;
use Tranquillus::Doc;
use Tranquillus::DB;
use Tranquillus::Data;
use Tranquillus::Util;
use Tranquillus::Proxy;

use Data::Dumper;

my $module_name      = 'CustomData';
my $description      = 'An example module with custom data routes';
my $module_url_token = 'custom-data';

sub parm_parse_rules {
    my %parm_parse_rules = ( name => { where_type => 'text', re => '[^A-Za-z0-9.-]', }, );
    return \%parm_parse_rules;
}

########################################################################
### For simple configurations there should be no custom changes past
### this point...
########################################################################
sub setup_routes {
    my ( $self, $index, $config_dir ) = @_;

    # Get the "auto-discovered" routes
    my $module_config = Tranquillus::Config->read_configs(
        {
            config_dir       => $config_dir,
            description      => $description,
            module_name      => $module_name,
            module_url_token => $module_url_token,
            parm_parse_rules => parm_parse_rules(),
        }
    );
    my @routes = @{ $module_config->{routes} };

    $index->{$module_name} = $module_config;

    # Add the "auto-discovered" data routes
    foreach my $config (@routes) {
        if ( !exists $config->{custom_data} ) {
            my $data_route = $config->{data_route};
            get "$data_route" => sub { Tranquillus::DB->do_data($config) };
        }
    }

    # Add custom data routes here...
    foreach my $config (@routes) {
        if ( exists $config->{custom_data} ) {
            my $link       = $config->{link};
            my $data_route = $config->{data_route};
            if ( $link eq 'circle' ) {
                get "$data_route" => sub { circle($config) };
            }
            elsif ( $link eq 'epub' ) {
                get "$data_route" => sub { get_epub($config) };
            }
        }
    }
    return 1;
}

sub circle {
    my $rt_config = shift;

    my $radius;
    my $pi           = 3.14159265;
    my @column_names = (qw(radius diameter area circumference));
    my $valid_parms  = Tranquillus::Util->get_valid_parms($rt_config);

    my %result = (
        valid_parms  => $valid_parms,
        column_names => \@column_names,
    );

    if ( exists $valid_parms->{radius} && $valid_parms->{radius} =~ m/^\d+(\.\d*){0,1}$/ ) {
        $radius = $valid_parms->{radius};
    }

    if ( defined $radius && $radius >= 0 ) {
        my %rslt = (
            'area'          => sprintf( "%0.6f", $pi * $radius * $radius ),
            'diameter'      => sprintf( "%0.6f", $radius * 2.0 ),
            'circumference' => sprintf( "%0.6f", $pi * $radius * 2.0 ),
            'radius'        => sprintf( "%0.6f", $radius ),
        );

        push @{ $result{data} }, \%rslt;
    }
    else {
        $result{errors} = 'Parameter "radius" is missing, invalid, or out of range.';
        @{ $result{data} } = ();
    }

    Tranquillus::Data->return_custom_data( $rt_config, \%result );
}

sub get_epub {
    my $rt_config = shift;

    my $valid_parms = Tranquillus::Util->get_valid_parms($rt_config);

    my $base_route = "http://www.gutenberg.org/cache/epub";

    my $file_name;
    if ( exists $valid_parms->{file} ) {
        $file_name = $valid_parms->{file};
    }
    unless ($file_name) {
        Tranquillus::Util->return_error( 'BAD_QUERY', "No filename" );
    }
    my ($file_id) = $file_name =~ m/(\d+)/;

    unless ($file_id) {
        Tranquillus::Util->return_error( 'BAD_QUERY', "No file id" );
    }

    my $file_route = join( '/', $base_route, $file_id, $file_name );

    Tranquillus::Proxy->proxy_request( 'http://status.savanttools.com/?code=403', $file_name );

    #Tranquillus::Proxy->proxy_request( $file_route, $file_name );
}

true;
