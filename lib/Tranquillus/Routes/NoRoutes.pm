package Tranquillus::Routes::NoRoutes;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Config;
use Tranquillus::Doc;
use Tranquillus::DB;

my $module_name      = 'NoRoutes';
my $description      = 'An example module with no routes-- not that it makes any sense to have such a thing.';
my $module_url_token = 'no-routes';

sub parm_parse_rules {
    my %parm_parse_rules;
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
