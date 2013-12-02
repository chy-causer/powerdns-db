use Test::More;

use strict;
use warnings;
use Data::Dumper;

use PowerDNS::DB::Test;
use PowerDNS::Validator::Basic;
use PowerDNS::Validator::Deny;
use Test::PowerDNS::Validator;

my $pdns = PowerDNS::DB::Test->new();

# Retrieve example.org
my $example_org = $pdns->domains->find({
        name => 'example.org'
});

my $basic_validator = PowerDNS::Validator::Basic->new( { db => $pdns } );

sub reset_db {
    $pdns = PowerDNS::DB::Test->new();
    $example_org = $pdns->domains->find({
            name => 'example.org'
        });
    $basic_validator = PowerDNS::Validator::Basic->new( { db => $pdns } );
}

subtest 'validate record creation' => sub {
    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                name      => 'a-record-1.example.org',
                domain_id => $example_org->id,
                content   => '192.168.1.1',
                type      => 'A',
                ttl       => '14400',
            }
        ),
        '^Record already exists$',
        'Should not be allowed to create duplicate records'
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                domain_id => $example_org->id,
                content   => '192.168.1.1',
                type      => 'A',
                ttl       => '14400',
            }
        ),
        '^Missing required field \'name\'$',
        'Should pick up on missing fields'
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                domain_id => $example_org->id,
                name      => 'new-cname.example.org',
                content   => 'nonexistent.example.org',
                type      => 'CNAME',
                ttl       => '14400',
            }
        ),
        '^CNAME record points to non-existent host nonexistent.example.org$',
        "Should pick up on cname creation pointing to non-existent hosts"
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                domain_id => $example_org->id,
                name      => 'new-cname.example.org',
                content   => 'nonexistent.example.org',
                type      => 'A',
                ttl       => '14400',
            }
        ),
        '^"A" record does not have a valid IP address$',
        "Should validate A record is an IP"
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                domain_id => $example_org->id,
                name      => 'new-mx.example.org',
                content   => 'a-record-1.example.org',
                type      => 'MX',
                ttl       => '14400',
            }
        ),
        "Missing required field 'prio'",
        "Should validate missing prio",
    );
};

subtest 'validate record deletion' => sub {

    # Find a CNAME
    my $cname_record = $pdns->records->search( { type => 'CNAME', } )->[0];

    # Find its A record
    my $a_record = $pdns->records->find(
        {
            type => 'A',
            name => $cname_record->content,
        }
    );

    ok_validator_has_warning(
        $basic_validator->validate( 'delete records', { id => $a_record->id } ),
'^Deleting record will cause \d other records? to be orphaned\. These records will be deleted$',
        'Deleting a record should carry a warning'
    );

    # Delete the CNAME. Should get no error now
    $pdns->records->delete( {id => $cname_record->{id}} );

    ok_validator_no_warnings(
        $basic_validator->validate( 'delete records', { id => $a_record->id, } ),
'Deleting "A" record without anything dependent on it should give no warnings'
    );

    ok_validator_no_errors(
        $basic_validator->validate( 'delete records', { id => 1 } ),
        'Should be able to delete a record by its id'
    );
};

subtest 'test record update' => sub {
    reset_db;


    # Pull an example A record to update
    my $a_record = $pdns->records->search({
            name => 'a-record-with-cname.example.org',
            type => 'A',
        })->[0];

    # Check cannot update fields that cannot be updated
    foreach my $field (qw(type id domain_id name)) {
        ok_validator_has_error(
            $basic_validator->validate(
                'update record',
                $a_record,
                {
                    $field => 'new value',
                }
            ),
            "Cannot update field '$field'"
        );
    };
};

subtest 'test record fields' => sub {
    reset_db;

    # Test RFC compliance
    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                name => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.example.org',
                domain_id => $example_org->id,
                content   => '192.168.1.1',
                type      => 'A',
                ttl       => '14400',
            }
        ),
        'too long for rfc1035',
        'Should bail on extra long subdomain lengths'
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                name => 'short-ttl.example.org',
                domain_id => $example_org->id,
                content   => '192.168.1.1',
                type      => 'A',
                ttl      => 1,
            }
        ),
        'TTL is too short',
        'TTLs should be sanity checked for length'
    );

    ok_validator_has_error(
        $basic_validator->validate(
            'create record',
            {
                name => 'short-ttl.example.org',
                domain_id => $example_org->id,
                content   => '192.168.1.1',
                type      => 'A',
                ttl       => 14400,
                prio      => 'wibble',
            }
        ),
        'Prio must be an integer between 0 and 9',
        'Prio should be sanity checked for length'
    );
};

subtest 'Validate record bulk update' => sub {
    ok_validator_has_error(
        $basic_validator->validate(
            'bulk update records',
            {
                type => 'A',
            },
            {
                name => 'invalid.example.org'
            }
        ),
        qr'^Cannot bulk update the field name. You will need to update each record individually$',
        'Cannot bulk update the name field'
    )
};



# Test that validations are hooking into the whole infrastructure by using the
# Deny validator. No records should be able to be created.
subtest 'test validation hooking into DB infrastructure' => sub {

    $pdns->add_validator( PowerDNS::Validator::Deny->new );

    # Create a new perfectly valid A record. This should
    # be denied by the Deny validator
    my $denied_record = $pdns->records->create(
        {
            name      => 'new-a-record.example.org',
            type      => 'A',
            domain_id => $example_org->id,
            content   => '192.168.1.1',
        }
    );

    ok !$denied_record, "A Deny validator should deny anything";

    ok_validator_has_error(
        $pdns->last_validation,
        "Denied by PowerDNS::Validator::Deny",
        "Should get back an error message from the Deny validator"
    );
};

done_testing;
