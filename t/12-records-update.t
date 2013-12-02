use Test::More;

use strict;
use warnings;

use PowerDNS::DB::Test;
use Test::PowerDNS::Validator qw(ok_validator_has_errors ok_validator_has_error);
use Data::Dumper;

my $pdns = PowerDNS::DB::Test->new();

# Retrieve example.org
my $example_org = $pdns->domains->find({
        name => 'example.org'
});

# Retrieve A record
#
my $record_fields = {
    name => 'a-record-1.example.org',
    type => 'A',
};

# Retrieve CNAME
my $cname_record = $pdns->records->find({
        name => 'cname.example.org',
        type => 'CNAME'
    });
die "Cannot bootstrap test environment" if not $cname_record;


subtest 'test valid updates' => sub {

    my $a_record = $pdns->records->find($record_fields);

    my $valid_submissions = [
        { content => '192.168.1.222' }, # PTR record will be updated because a PTR domain exists
        { ttl => 3001 },
        { content => '192.168.1.223', ttl => 3002 },
        { prio => 3 }, # Not strictly valid as it's an A rec, but testing it so you know it is valid
    ];
          
    foreach my $valid_submission (@$valid_submissions) {
        my $record = $pdns->records->find($record_fields) or die "Bad fixture data";
        ok( $record->update(
            $valid_submission
        ), "Should update record without issue using valid update data" )
            or diag($valid_submission, $pdns->last_validation);

        # Find the record again
        my $updated_record = $pdns->records->find({ id => $record->id });
        foreach my $field ( keys $valid_submission ) {
            is($updated_record->$field, $valid_submission->{$field},
                "Should be able to update valid $field with $valid_submission->{$field}");
        };
    };
};

# Test invalid updates fail
subtest 'test invalid submissions' => sub {
    my $a_record = $pdns->records->find($record_fields);
    my $invalid_submissions;

    # A record
    $invalid_submissions = [
        { content => 'garbage' },
        { ttl => '1x' },
        { name => 'sensible-but-cannot-update-name.example.org' },
        { prio => -1 },
    ];

    foreach my $invalid_submission (@$invalid_submissions) {
        $pdns->reset;

        my $record = $pdns->records->find($record_fields);
        my $failed_update = $record->update( $invalid_submission );

        is ($failed_update, undef, 'Should fail update if given invalid submission')
            or diag(Dumper($invalid_submission));
        my $record_after_failed_update = $pdns->records->find({id => $record->id});
        is_deeply(\{$record->get_columns}, \{$record_after_failed_update->get_columns}) or diag(
            "Updated with invalid submission: \n" . Dumper($invalid_submission)
        );
    };

    $invalid_submissions = [
        { content => 'missing-parent.example.org' }
    ];

    foreach my $invalid_submission (@$invalid_submissions) {
        my $failed_update = $pdns->records->update(
            $cname_record->id,
            $invalid_submission
        );

        is ($failed_update, undef, 'Should fail update if given invalid submission');
        my $record_after_failed_update = $pdns->records->find({id => $cname_record->id});
        is_deeply(\{$cname_record->get_columns}, \{$record_after_failed_update->get_columns}) or diag(
            "Updated with invalid submission: \n" . Dumper($invalid_submission)
        );
    };
};

=head2 UNUSED
subtest 'Test bulk updates' => sub {
    my $valid_submissions = [
        [
            { name => 'a-record-1.example.org'},
            { ttl => 3601 },
        ],
        [
            { type => 'CNAME'},
            { ttl => 3602 },
        ],
        [
            { domain_name => 'example.org' },
            { ttl => 3603 },
        ],
        [
            #Valid, but a stupid update to do
            { type => 'MX' },
            { prio => 9 },
        ]
    ];

    foreach my $valid_submission ( @$valid_submissions ) {
        my ( $conditions, $updated_values ) = @$valid_submission;
        my $initial_matching_records = $pdns->records->search($conditions);

        # Something is wrong if we do not have the fixture data we need for
        # testing
        die "Need to fix up fixture data for bulk updates. " .
            "No matching records found for the following conditions:\n" .
            Dumper($conditions) unless $initial_matching_records;

        ok($pdns->records->bulk_update($conditions, $updated_values))
            or diag( $pdns->last_validation);
    }

    my $invalid_submissions = [
        [
            { name => 'a-record-1.example.org' },
            { name => 'a-record-1x.example.org' }
        ]
    ];

    foreach my $invalid_submission ( @$invalid_submissions ) {
        my ( $conditions, $updated_values ) = @$invalid_submission;
        my $initial_matching_records = $pdns->records->search($conditions);

        # Something is wrong if we do not have the fixture data we need for
        # testing
        die "Need to fix up fixture data for bulk updates. " .
            "No matching records found for the following conditions:\n" .
            Dumper($conditions) unless $initial_matching_records;

        my $undef = $pdns->records->bulk_update($conditions, $updated_values);
        is($undef, undef, "Should return undef on a failed bulk update");
        ok_validator_has_errors($pdns->last_validation);
    }
};
=cut
        


done_testing;
