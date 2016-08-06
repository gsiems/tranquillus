requires "Dancer2"                   => "0.163000";
requires "DateTime"                  => "0";
requires "Data::Dumper"              => "0";
requires "POSIX"                     => "0";
requires "DBIx::Connector"           => "0";

requires "Plack::Middleware::CrossOrigin"        => "0.012";
requires "Plack::Middleware::XFrameOptions::All" => "0.2";
requires "Plack::Middleware::IEnosniff"          => "0.02";

recommends "DBD::Pg"          => "0";
recommends "YAML"             => "0";
recommends "JSON::XS"         => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

on "test" => sub {
    requires "Test::More"            => "0";
    requires "HTTP::Request::Common" => "0";
};

