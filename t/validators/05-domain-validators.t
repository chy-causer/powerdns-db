use Test::More;

use strict;
use warnings;

use PowerDNS::DB::Test;
use Test::PowerDNS::Validator;

my $pdns = PowerDNS::DB::Test->new();

#Test you cannot add a duplicate domain
subtest 'Existing domain creation' => sub {
    my $null = $pdns->domains->create({
            name => 'example.org',
            soa => {
                content => 'ns.example.org. hostmaster.example.org. 1 2 3 4 5'
            }
    });
    is $null, undef, "Should not create duplicate domain";

    ok_validator_has_error($pdns->last_validation, qr'^Domain exists$',
        "Duplicate domain creation should result in a 'duplicate' error message"
    );
};


# Test you cannot add a domain without providing SOA info
subtest 'Missing SOA domain creation' => sub {
    my $null = $pdns->domains->create({
            name => 'new.example.org',
    });

    is $null, undef, "Should not create duplicate domain";

    ok_validator_has_error($pdns->last_validation, qr'Missing SOA information',
        "Should not create a domain without SOA information"
    );
};



# Test that a new domain results in an SOA record for this domain
subtest 'SOA validation' => sub {
    my $valid_soa_content = 'ns.new.example.org. hostmaster.new.example.org. 1 2 3 4 5';
    my $invalid_soa_content = 'ns.new.example.org. hostmaster@new.example.org tribble 2 3 4 5';

    my $null = $pdns->domains->create({
            name => 'fail.example.org',
            soa => {
                content => $invalid_soa_content
            }
    });
    is $null, undef, "Should not create domain with invalid SOA record";
    
    # Knock off all the things wrong with the record in one go
    foreach my $error ('Serial is not an integer for SOA', 'Invalid hostmaster email for SOA') {
        ok_validator_has_error($pdns->last_validation, $error,
            "Should pick up on SOA errors"
        );
    };

    my $domain = $pdns->domains->create({
            name=> 'new.example.org',
            soa => {
                content => $valid_soa_content,
            }
    });
    ok_validator_no_errors($pdns->last_validation);

    my $soa_record_for_domain = $pdns->records->search({
            domain_name => 'new.example.org',
            type        => 'SOA',
    });

    # In integer context
    is $soa_record_for_domain, 1, "New domain should have one SOA record"
        or BAIL_OUT("Cannot carry on with this suite");

    is $soa_record_for_domain->{content}, $valid_soa_content, 'SOA content should be returned unaltered';
};

done_testing;
