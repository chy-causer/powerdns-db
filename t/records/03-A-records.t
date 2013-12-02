use Test::More;

use strict;
use warnings;

use PowerDNS::DB::Test;
use Data::Dumper;

my $pdns = PowerDNS::DB::Test->new();

# Retrieve example.org
my $example_org = $pdns->domains->find({
        name => 'example.org'
    });

subtest "Test record creation" => sub {

    my $a_record = $pdns->records->create({
            name => 'test.example.org',
            type => 'A',
            domain_name => 'example.org',
            content => '192.168.1.100',
            ttl => '3600',
    });

    isa_ok($a_record, 'PowerDNS::DB::Schema::Result::Record', '$a_record');
};

# Create round robin
#
# Nothing particularly special about this, but
# I just want to make sure no Basic validator gets in the way
subtest 'Test round robin creation' => sub {
    my $second_a_record = $pdns->records->create({
            name => 'test.example.org',
            type => 'A',
            domain_id => $example_org->id,
            content => '192.168.1.101',
            ttl => '3600',
    });

    isa_ok($second_a_record, 'PowerDNS::DB::Schema::Result::Record', '$second_a_record');

    # Check that we now have two records in the DB
    my $number_of_test_a_records = $pdns->records->search({
            name => 'test.example.org',
            domain_id => $example_org->id,
    });

    # Implicit check for explicit domain_id argument and 
    # implicit domain_name argument
    is $number_of_test_a_records, 2, "Round robin records should be possible";
};

# For Implicit PTR creation, see 02-ptr.t
done_testing;
