package Tranquillus;
use Dancer2;

use Data::Dumper;

our $VERSION = '0.1';

use FindBin;
FindBin::again();
our $lib_dir = "$FindBin::Bin/../lib";

my @errors;
my %index;
my @module_list;
my @modules;
my @route_mods;

my $routes_dir = "$lib_dir/Tranquillus/Routes";

setup_modules($routes_dir);

foreach my $cfg ( sort keys %index ) {
    push @module_list, $index{$cfg};
}

=pod setup_modules

=cut

sub setup_modules {
    my ($routes_dir) = @_;
    opendir( my $dh, $routes_dir ) || die "Can't opendir $routes_dir: $!";
    @route_mods =
        grep { -f $_ }
        grep { $_ =~ m/\.pm$/ } map { "$routes_dir/$_" } readdir($dh);
    closedir $dh;

    foreach my $idx ( 0 .. $#route_mods ) {
        my $file   = $route_mods[$idx];
        my @a      = ( split /[\/\.]/, $file )[ -4 .. -2 ];
        my $module = join( '::', @a );

        eval qq{package         # hide from PAUSE
            Tranquillus::_firesafe; # just in case
            require $module;    # load the module
        };

        if ($@) {
            push @errors, $@;
        }
        else {
            my ($config_dir) = $file =~ m/^(.+)\.pm/;
            $module->setup_routes( \%index, $config_dir );
            push @modules, $module;
        }
    }
}

get '/' => sub {

    if ( config->{environment} eq 'development' ) {
        my %h = (
            'lib_dir'     => $lib_dir,
            'route_mods'  => \@route_mods,
            'modules'     => \@modules,
            'errors'      => \@errors,
            'module_list' => Dumper \@module_list,
            'index'       => \%index,
            'route_mods'  => \@route_mods,
        );

        template 'index', { 'dev_data' => Dumper \%h, 'module_list' => \@module_list };
    }
    else {
        template 'index', { 'module_list' => \@module_list };
    }

};

true;
