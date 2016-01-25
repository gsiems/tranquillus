package Tranquillus::Routes::pTracker;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Config;
use Tranquillus::Doc;
use Tranquillus::DB;

my $module_name      = 'pTracker';
my $description      = 'Using pTracker tables as example RESTful reporting routes';
my $module_url_token = 'ptracker';

sub parm_parse_rules {
    my %parm_parse_rules = (
        analyteCode         => { where_type => 'iu_text', re => '[^A-Z0-9-]', },
        analyteGroupCode    => { where_type => 'iu_text', re => '[^A-Z0-9-]', },
        dataAfter           => { where_type => '>=_date', },
        geoAreaTypeCode     => { where_type => 'il_text', },
        gtlt                => { where_type => 'text',    re => '[^<>]', },
        siteId              => { where_type => 'pos_int', },
        sampleDate          => { where_type => '=_date', },
        specificAreaName    => { where_type => 'cu_text', re => '[^A-Z0-9_.-]', },
        specificGeoAreaCode => { where_type => 'text',    re => '[^A-Za-z0-9_-]', },
        stationId           => { where_type => 'cu_text', re => '[^A-Z0-9-]', },
        stationName         => { where_type => 'cu_like', re => '[^A-Z0-9]', },
        stationPurpose      => { where_type => 'cu_text', re => '[^A-Z0-9 ]', },
        stationType         => { where_type => 'cu_text', re => '[^A-Z0-9 ]', },
    );
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

    return 1;
}

true;
