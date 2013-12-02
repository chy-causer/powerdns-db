use Test::More;

use 5.014;
use strict;
use warnings;

use PowerDNS::DB::Test;
use Data::Dumper;

my $pdns = PowerDNS::DB::Test->new();

# Retrieve example.org
my $example_org = $pdns->domains->find({
        name => 'example.org'
});

my $valid_record_submissions = {
    A => {
        name        => 'test.example.org',
        type        => 'A',
        domain_name => 'example.org',
        content     => '192.168.1.100',
        ttl         => '3600',
    },
    CNAME => {
        name        => 'created-name.example.org',
        type        => 'CNAME',
        content     => 'a-record-3.example.org',
        domain_name => 'example.org'
    },

    MX => {
        name        => 'new-mx-record.example.org',
        type        => 'MX',
        content     => 'a-record-3.example.org',
        domain_name => 'example.org',
        prio        => '0'
      }

};

subtest "Test record creation" => sub {
    foreach my $record_type ( keys $valid_record_submissions ) {
        my $fields = $valid_record_submissions->{$record_type};
        my $record = $pdns->records->create($fields);
        isa_ok( $record, 'PowerDNS::DB::Result::Record', '$record' )
          or diag( "Failed to create record with the following fields: \n"
              . Dumper($fields) . "\n"
              . "Validation result:\n"
              . $pdns->last_validation );
    }
};

my $invalid_record_submissions = {
    A => {
        'Non existent domain' => {
            name        => 'test.non-existent-domain.org',
            type        => 'A',
            content     => '192.168.1.100',
            domain_name => 'non-existent-domain.org',
            ttl         => '3600',
        },
        'A record already exists' => {
            name        => 'a-record-1.example.org',
            type        => 'A',
            content     => '192.168.1.1',
            domain_name => 'example.org',
        },
        'Missing type' => {
            name        => 'missing-type.example.org',
            content     => '192.168.1.100',
            domain_name => 'example.org',
            ttl         => '3600',
        },
    },
    CNAME => {
        'CNAME already exists' => {
            name        => 'created-name.example.org',
            type        => 'CNAME',
            content     => 'a-record-3.example.org',
            domain_name => 'example.org'
        }
    },
    MX => {
        'Missing prio' => {
            name        => 'failed-mx-record.example.org',
            type        => 'MX',
            content     => 'a-record-3.example.org',
            domain_name => 'example.org',
        }
    }
};

subtest "Test invalid submission" => sub {
    foreach my $type ( keys $invalid_record_submissions ) {
        foreach my $error ( keys $invalid_record_submissions->{$type} ) {
            my $fields = $invalid_record_submissions->{$type}->{$error};
            my $null   = $pdns->records->create($fields);
            is( $null, undef, "Created record with invalid submission: $error" )
              or diag( Dumper($fields) );
        }
    }
};

# Create round robin
#
# Nothing particularly special about this, but
# I just want to make sure no Basic validator gets in the way
subtest 'Test round robin creation' => sub {
    my $second_a_record = $pdns->records->create(
        {
            name      => 'test.example.org',
            type      => 'A',
            domain_id => $example_org->id,
            content   => '192.168.1.101',
            ttl       => '3600',
        }
    );

    isa_ok( $second_a_record, 'PowerDNS::DB::Result::Record',
        '$second_a_record' );

    # Check that we now have two records in the DB
    my $test_a_records = $pdns->records->search(
        {
            name      => 'test.example.org',
            domain_id => $example_org->id,
            type      => 'A',
        }
    );

    # Implicit check for explicit domain_id argument and
    # implicit domain_name argument
    is $test_a_records->count, 2, "Round robin records should be possible";
};

# For Implicit PTR creation, see 02-ptr.t
done_testing;
