use Test::More;

use strict;
use warnings;

use PowerDNS::DB::Test;
use Test::PowerDNS::Validator;
use Test::Exception;
use Data::Dumper;

my $pdns = PowerDNS::DB::Test->new();

my $example_org = $pdns->domains->find({name => 'example.org'});
my $inaddr_arpa = $pdns->domains->find({name => '1.168.192.in-addr.arpa'});
my $ip6_arpa = $pdns->domains->find({name => '0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa'});
die "Bad fixture data" if not ( $example_org and $inaddr_arpa and $ip6_arpa );
    

# Add an A record, test that a PTR is created automatically when requested, and not when not
subtest 'Implicit creation of PTR records' => sub {
    my @new_records = (
        {
            forward => {
                name      => 'a-record-100.example.org',
                type      => 'A',
                content   => '192.168.1.100',
                domain_id => $example_org->id,
            },

            reverse => {
                name => '100.1.168.192.in-addr.arpa',
                type => 'PTR',
                content => 'a-record-100.example.org',
                domain_id => $inaddr_arpa->id,
            }
        },
        {
            forward => {
                name      => 'aaaa-record-001.example.org',
                content   => '2001:db8::1:1',
                type      => 'AAAA',
                domain_id => $example_org->id,
            },

            reverse => {
                name => '1.0.0.0.1.' . '0.' x 19 . '8.b.d.0.1.0.0.2.ip6.arpa',
                type => 'PTR',
                content => 'aaaa-record-001.example.org',
                domain_id => $ip6_arpa->id,
            }
        },
    );

    foreach my  $new_record ( @new_records ) {

        my $record = $pdns->records->create(
            $new_record->{forward},
            { create_ptr => 1, }
        );
        ok_validator_no_errors($pdns->last_validation);
        isa_ok($record, 'PowerDNS::DB::Result::Record');

        # Look for pointer
        my $ptr_record = $pdns->records->search(
            $new_record->{reverse}
        );

        is $ptr_record->count, 1, "A record should automatically create PTR record";
    }
};

subtest 'Update of paired records' => sub {
    my $forward_record = $pdns->records->find({name => 'a-record-1.example.org'})
        or die "Bad fixure data. Missing A record";
    my $reverse_record = $pdns->records->find({name => '1.1.168.192.in-addr.arpa'})
        or die "Bad fixure data. Missing PTR record";

    # Sanity check that reverse_record is working before the update
    isa_ok($forward_record->reverse_record, 'PowerDNS::DB::Result::Record');

    # Perform the update
    $forward_record->update({ content => '192.168.1.222'}) or fail($pdns->last_validation);

    # Get reverse_record from storage. Should have updated in place
    is($reverse_record->get_from_storage->name,
        '222.1.168.192.in-addr.arpa',
        'Test explicit paired record retrieval'
    );

    isa_ok($forward_record->reverse_record, 'PowerDNS::DB::Result::Record');
    is($forward_record->reverse_record->name, '222.1.168.192.in-addr.arpa', 'Should update reverse record');

    throws_ok {
        $forward_record->update({ content => '172.16.1.100'});
    } 'DBIx::Class::Exception';
    like $@, qr'Cannot update a paired record when we do not host the PTR domain';
};

subtest 'Test failure of reversing irreversible records' => sub {
    my @irreversible_forward_records = (
        {
            name      => 'a-record-100.example.org',
            type      => 'A',
            content   => '172.16.1.100',
            domain_id => $example_org->id,
        },
    );
    foreach my $irreversible_forward_record (@irreversible_forward_records) {
        throws_ok {
            my $failed_record = $pdns->records->create( $irreversible_forward_record,
                  { create_ptr => 1, }
            );
        } 'DBIx::Class::Exception',
          "Record creation should bail if no PTR can be created";
        like $@, qr'Cannot create PTR when no domain is available';

        my $non_ptr_record = $pdns->records->create(
            $irreversible_forward_record,
            { create_ptr => 0, }
        );

        isa_ok( $non_ptr_record, 'PowerDNS::DB::Result::Record',
            '$non_ptr_record')
            or diag($pdns->last_validation);
    }
};

done_testing;

=pod

=head1 PTR tests

This file should test various functions which create PTR records.

=cut
