package Tranquillus::DB;
use Dancer2 appname => 'Tranquillus';

use Tranquillus::Data;
use Tranquillus::DB::Connection;
use Tranquillus::DB::Query;
use Tranquillus::DB::Result;
use Tranquillus::Util;

sub do_data {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ($rt_config) = @_;

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
    if ( $rt_config->{use_streaming} ) {
        $query->{use_streaming} = 1;
    }

    if ( exists $valid_parms->{nullValue} ) {
        $query->{nullValue} = $valid_parms->{nullValue};
    }

    Tranquillus::DB::Result->return_query_result($query);
}

sub do_search_suggestions {
    my $self;
    $self = shift if ( ( _whoami() )[1] ne (caller)[1] );
    my ( $rt_config, $search_suggestions ) = @_;

    my $deprecation_policy = Tranquillus::Util->deprecation_policy($rt_config);
    if ( $deprecation_policy->{status} == 2 ) {

        # TODO: redirect or error of some form? 404? Is there a best
        # practice for RESTful?
        redirect '/';
    }

    my $result_size = $rt_config->{search_suggetion_size} || config->{search_suggetion_size} || 5;

    if ( scalar @{ $rt_config->{fields} } != 1 ) {
        Tranquillus::Util->return_error('BAD_RT_CONF');
    }

    my ($field) = @{ $rt_config->{fields} };

    my $query = join( ' ', 'SELECT', $field->{db_column}, $rt_config->{from}, $rt_config->{order_by} );

    unless ( scalar @{$search_suggestions} ) {

        my $dbh = Tranquillus::DB::Connection->get_dbh( $rt_config->{database} );

        my $sth = $dbh->prepare($query);
        unless ($sth) {
            Tranquillus::Util->return_error('BAD_QUERY');
        }

        $sth->execute();

        foreach my $row ( @{ $sth->fetchall_arrayref() } ) {
            push @{$search_suggestions}, $row->[0];
        }
    }

    my @data      = ();
    my $parm_name = $field->{name};
    my $q         = lc params->{$parm_name};
    $q =~ s/^\s+//;
    $q =~ s/\s+$//;

    # Because back-slashes can be an issue:
    $q =~ s/\\/\\\\/g;

    if ($q) {
        my $re = ( exists $field->{re} ) ? $field->{re} : 'A-Za-z0-9';
        my $foo = $q;

        if ( $foo !~ m/^[$re]*$/ ) {
            $foo =~ s/[^$re]+/.*/g;
        }
        if ( scalar @{$search_suggestions} && $foo ) {
            my @sub = grep { defined $_ && $_ =~ m/$foo/i } @{$search_suggestions};

            # "proper" left to right match entries
            $q =~ s/\./\\./g;
            my @sub2 = grep { $_ =~ m/^$q/i } @sub;

            # start match on left with rest further down
            if ( scalar @sub2 < $result_size ) {
                my %t = map { $_ => 1 } @sub2;
                push @sub2, $_ for ( grep { !$t{$_}++ } grep { $_ =~ m/^$foo/i } @sub );
            }

            # grab whatever to fill in the remainder
            if ( scalar @sub2 < $result_size ) {
                my %t = map { $_ => 1 } @sub2;
                push @sub2, $_ for ( grep { !$t{$_}++ } @sub );
            }

            # grab only the first "result_size" results
            foreach my $idx ( 0 .. $result_size - 1 ) {
                next unless ( $sub2[$idx] );
                my %h;
                $h{q} = $sub2[$idx];
                push @data, \%h;
            }
            undef @sub;
            undef @sub2;
        }
    }

    my %valid_parms = ( $parm_name => params->{$parm_name} );
    my @column_names = ();

    my %rslt = (
        valid_parms  => \%valid_parms,
        column_names => \@column_names,
        data         => \@data,
        query        => $query,
    );

    my $return = Tranquillus::Data->return_result( \%rslt );

    undef @data;

    return $return;
}

sub _whoami {
    my @whoami = caller;
    return @whoami;
}

true;
