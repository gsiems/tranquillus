#!/usr/bin/env perl
use warnings;
use strict;

use Perl::Critic;
use FindBin;

my $critic = Perl::Critic->new();

my $lib_path = "$FindBin::Bin/lib";

my @files = `find $lib_path -type f -name "*.pm"`;
chomp @files;

foreach my $file (@files) {
    my @violations = $critic->critique($file);
    if (@violations) {
        print "\n################################\n$file:\n", @violations;
    }
}
