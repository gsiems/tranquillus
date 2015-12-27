package Tranquillus::Routes::NoRoutes;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Config;
use Tranquillus::Doc;
use Tranquillus::DB;

my $module_name   = 'NoRoutes';
my $description   = 'An example module with no routes-- not that it makes any sense to have such a thing.';
my $module_prefix = 'no-routes';

my @routes;

sub arg_parse_rules {
    my %arg_parse_rules;
    return \%arg_parse_rules;
}

########################################################################
### For simple configurations there should be no custom changes past
### this point...
########################################################################
sub setup_routes {
    my ( $self, $index, $config_dir ) = @_;

    $index->{$module_name}{module_name} = $module_name;
    $index->{$module_name}{description} = $description;
    $index->{$module_name}{route}       = "/$module_prefix";

    my $arg_parse_rules = arg_parse_rules();

    # Get the "auto-discovered" routes
    my $module_config =
        Tranquillus::Config->read_configs( $config_dir, $arg_parse_rules, $module_name, $module_prefix, $description );
    my @routes = @{ $module_config->{routes} };

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
