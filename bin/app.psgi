#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Tranquillus;

use Plack::Builder;

builder {
    enable 'CrossOrigin', origins => '*';
    enable 'XFrameOptions::All', policy => 'deny';
    enable 'IEnosniff';
    Tranquillus->to_app;
}
