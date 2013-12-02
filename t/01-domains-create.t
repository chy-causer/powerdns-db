use Test::More;

use strict;
use warnings;
use Data::Dumper;

use PowerDNS::DB::Test;
use PowerDNS::Validator::Domains;
use Test::PowerDNS::Validator;

my $pdns = PowerDNS::DB::Test->new();

my $soa_row = {
    content => 'new.example.edu. hostmaster.example.exu 1 2 3 4 5'
};
    

# Test you can add a domain
my $number_of_domains = $pdns->domains->count;
my $new_domain = $pdns->domains->create({
        name => 'new.example.edu',
        type => 'MASTER',
        soa => $soa_row,
});
ok_validator_no_errors($pdns->last_validation)
    or BAIL_OUT("Cannot continue testing if no domain is created");

ok $new_domain, "New domain should be stored" or
    diag($pdns->last_validation);
ok $pdns->domains->count == ++$number_of_domains, "Add a domain";

is $pdns->records->search({
        type => 'SOA',
        name => 'new.example.edu',
        content => $soa_row->{content},
    })->count, 1, "Should implicitly create SOA record for new domain";

#Test you cannot add a duplicate domain
my $null = $pdns->domains->create({
        type => 'NATIVE',
        name => 'new.example.edu',
        soa => $soa_row,
});
is $null, undef, "Should not create duplicate domain";

done_testing;
