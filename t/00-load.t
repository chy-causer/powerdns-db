#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'PowerDNS::DB' ) || print "Bail out!\n";
}

diag( "Testing PowerDNS::DB $PowerDNS::DB::VERSION, Perl $], $^X" );
