package Tranquillus::DB;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Util;
use Tranquillus::DB::Result;
use Tranquillus::DB::Query;

sub do_data {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($rt_config) = @_;

    # TODO: cleanup/streamline the "config" flow
    # %args should revert to $args,
    # functions should not add to it but should create their own return

    my $deprecation_policy = Tranquillus::Util->deprecation_policy($rt_config);
    if ( $deprecation_policy->{status} == 2 ) {

        # TODO: redirect or error of some form? 404? Is there a best
        # practice for RESTful?
        redirect '/';
    }

    my $valid_parms = Tranquillus::Util->get_valid_parms($rt_config);

    my $query = Tranquillus::DB::Query->prep_query( $rt_config, $valid_parms );

    if ( exists $rt_config->{format} ) {
        $query->{format} = $rt_config->{format};
    }
    $query->{invalid_parms}      = Tranquillus::Util->get_invalid_parms($rt_config);
    $query->{deprecation_policy} = $deprecation_policy;

    Tranquillus::DB::Result->return_query_result($query);
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
