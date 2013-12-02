use utf8;

package PowerDNS::Validator::Records;

use 5.014;    # We want all the trimmings available to us
use Net::IP;
use Carp;
use Data::Dumper;
use Scalar::Util qw/reftype/;
use Regexp::Common qw/net/;
use Try::Tiny;

use parent qw(PowerDNS::Validator::Base);

=head1 NAME

 - PowerDNS::Validator::Records;

=head1 SYNOPSIS
 
See L<PowerDNS::Validator::Base> for further details.

=head1 DESCRIPTION


Validates record actions

=head1 METHODS

This method will return the schema object.

=head2 validate_create_record( $row, @extra_args)
=head2 validate_update_record( $row, $updated_columns, @extra_args)
=head2 validate_delete_record( $row, @extra_args)

Adds a warning if the number of record deletions > 3

Adds a warning if the number of dependent records > 0

=cut
sub validate_delete_record {
    my ( $self, $conditions ) = @_;
    die "Not implemented\n";

    my $result = $self->_new_result;

    # Warn if update will affect many records
    # (I'm clutching at a random number 3 but
    # we can change that at a later date. It will
    # not hinder anything.
    if ( ( my $records_affected = _db->records->search( {%$conditions} ) ) > 3 ) {
        $result->add_warning("%s records will be deleted", [$records_affected]);
    }

    my $dependent_records_count =
      $self->schema->records->dependent_records( {%$conditions} );

    if ($dependent_records_count > 0) {
        my $noun = $dependent_records_count > 1 ? 'records' : 'record';
        $result->add_warning(
            "Deleting record will cause %s child %s to be deleted",
            [ $dependent_records_count, $noun ]
        );
    }
    return $result;
}

sub validate_create_record {
    my ( $self, $row, $extra_parameters ) = @_;

    my $result = $self->_new_result;
    $row = $self->_sanitize_row($row);

    $extra_parameters ||= {};

    given ( $row->type ) {
        when (not $_ ~~ [qw/SOA/] ) {
            # Special case SOA because that is created at the same time
            # as the domain, so a domain_id is not yet available
            $result += $self->validate_field_presence(
                    $row, [ qw(domain_id) ]
                );
            continue;
        }
        when ( [qw/MX/] ) {
            $result += $self->validate_field_presence(
                    $row, [qw/prio/]
                );
        }
        default {
            $result += $self->validate_field_presence(
                    $row, [qw/name content type ttl/]
                );
                    
            $result += $self->validate_field_absence(
                    $row, [qw/id auth ordername change_date/]
                );
        }
    }

    # Do not continue validating because the validation will
    # have errors otherwise!
    return $result if $result->errors;

    $result += $self->validate_fields($row, $row->type);

    if ($self->schema) {
        $result += $self->validate_record_is_unique($row);

        $result->shortcircuit if $result->errors;

        # Validation based on type

        # The "continue" means that the thing falls through to the next match.
        # It is /not/ the same as a C switch statement.
        given ( $row->type ) {
            when ( [ qw/A AAAA/ ] ) {
                $result += $self->validate_round_robin( $row );
                continue;
            }
            default {
                $result += $self->validate_is_in_correct_domain( $row );
            }
        }
    }
    else {
        $result->add_warning("Skipping stateful checks");
    }
    return $result;
}


=head2 validate_round_robin($row_object)

Adds a warning if the creation of a row as defined by $row_object
will create a round robin

=cut

sub validate_round_robin {
    my ( $self, $row ) = @_;
    my $result = $self->_new_result;
    
    my $schema = $self->schema_or_fail;

    if (
        $schema->records->search(
            {
                name   => $row->name,
                type   => $row->type,
            }
        )->count > 0
      )
    {
        $result->add_warning(
            'Record %s already exists in database. ' .
            'New record will create a round robin',
            [ $row->name ]
        );
    }

    return $result;
}

=head2 validate_is_in_correct_domain

=over

=item Arguments: $row_object (that has a domain_id attribute), $schema

=item Return Value: $result

=back

Validates that, say name.best.example.org is attached to the correct domain.
Domain "best.example.org" will not create an error. Domain "example.org" will
not create an error. Domain "example.net" I<will> create an error.

Also gives an error if the domain_id maps to a non-existent domain.

=cut

sub validate_is_in_correct_domain {
    my ( $self, $row ) = @_;

    my $schema = $self->schema_or_fail;

    my $result = $self->_new_result;

    $result->short_circuit("Missing schema") if not $schema;

    my $domain = $schema->domains->find( {id => $row->domain_id} );

    if ( not $domain ) {
        $result->add_error("Domain id %s does not map to a domain", [ $row->domain_id ] );
        return $result;
    }
    if ( $row->name !~ /${\$domain->name}$/ ) {
        $result->add_error("Record %s does not belong in domain %s",
            [ $row->name, $domain->name ]
        );
    }
    return $result;
}

=head2 validate_record_is_unique($row_object, $schema)

Adds an error if the $row_object is already defined in the schema

Throws an exception if no schema has been defined.

=cut

sub validate_record_is_unique {
    my ( $self, $row ) = @_;
    my $result = $self->_new_result;

    my $schema = $self->schema_or_fail;
    
    die "Missing schema attribute in object" unless $schema;

    if (
        $schema->records->search(
            {
                name    => $row->name,
                content => $row->content,
                type    => $row->type,
            }
        )->count > 0
      )
    {
        $result->add_error("Record already exists", [], { row => $row });
    }
    return $result;
}


sub validate_update_record {
    my ( $self, $dirty_row, $updated_fields, $extra_params ) = @_;

    my $result = $self->_new_result;
    
    # Sometimes the updated_fields are in the $row object itself
    my $row;
    ( $row, $updated_fields ) = $self->_separate_clean_from_dirty($dirty_row, $updated_fields);

    # Only allow updates for allowed fields. Id and type are
    # not allowed
    #
    # Non existent types are not allowed either
    foreach my $field ( keys %$updated_fields ) {
        given( $field ) {
            when ( [qw(name domain_id id type)] ) {
                $result->add_error("Cannot update field '%s'", [$field]);
                continue;
            }
        }
    }

    # Bail out early if errors
    $result->die_if_errors;

    # Basic type checking of fields
    $result += $self->validate_fields($updated_fields, $row->type);


    if ( !keys %$updated_fields ) {
        return $result->add_error("No valid fields to update");
    }

    if ( $self->schema ) {
        if ( $row->type ~~ [qw/AAAA A/]
                and $updated_fields->content
                and $row->content ne $updated_fields->content
        ) {

            # Check that if the PTR is updated, that it can be updated
            $result += $self->validate_ptr_update( $row, $updated_fields->content );
        }
    }
    else {
        $result->add_warning('Skipping stateful checks');
    }

    return $result;
}


=head2 validate_fields($fields, $record_type)

Given $fields, will validate they are all valid for the given $record_type

=over

=item Fails on unknown fields

=item Runs L</validate_ttl_field>

=item Runs L</validate_prio_field> if it is an $record_type is an MX

=item Runs L</validate_content_field>

=item Runs L</validate_name_field>

=back

=cut

sub validate_fields {
    my ( $self, $fields, $record_type ) = @_;

    my $result = $self->_new_result;

    $record_type ||= $fields->type;

    # Search for unknown fields
    foreach my $field ( keys %$fields ) {
        if ( ! ( $field ~~ [ qw(id name content type ttl prio domain_id ordername auth change_date) ] ) ) {
            $result->add_error("Unknown field %s", [$field]);
        }
    }

    #Validate generic fields
    #
    # -- validate type
    #  - sanity check input
    carp "No type specified for field validation"
        if not $record_type;
    carp "Record type inconsistency"
        if defined $fields->type and $fields->type ne $record_type;
    #  - check that it is a valid type
    $result += $self->validate_type_field($record_type);


    # -- validate TTL
    $result += $self->validate_ttl_field($fields->ttl)
        if $fields->ttl;

    # -- validate prio
    # - Don't care if $record_type is not valid. It's their funeral...
    $result += $self->validate_prio_field($fields->prio)
        if ( $fields->prio );
        
    # -- validate content
    $result += $self->validate_content_field( $fields->content, $record_type)
        if $fields->content;

    if ( $fields->name ) {
        $result += $self->validate_name_field( $fields->name, $record_type );
    }

    return $result;
}

=head2 validate_prio_field($value)

Validates that 0 <= $value <= 9

=cut 
sub validate_prio_field {
    my ($self, $value) = @_;
    my $result = $self->_new_result;

    $result->add_error("Prio %s is invalid. Must be an integer between 0 and 9", [$value], { prio => $value })
        if not $value =~/\A[0-9]\z/;

    return $result;
}


=head2 validate_type_field($type)

For the moment, this fails validation for perfectly valid record types (see the
source for the definitive list, which includes AFSDB, DNSKEY and TXT.) You will get an error
"$type is not yet supported" for these.

If it is a completely unknown type you will see "Unknown record type $type"

=cut 

sub validate_type_field {
    my ( $self, $type ) = @_;
    my $result = $self->_new_result;
    
    given ($type) {
        when (
            [ qw[AFSDB CERT DNSKEY DS HINFO KEY LOC NAPTR NS NSEC RP RRSIG SPF SSHFP SRV TXT] ]
          )
        {
            $result->add_error("%s is not yet supported", [$type]);
        }
        when ( [ qw[A AAAA MX PTR CNAME SOA] ] ) {
            # All is well
        }
        default {
            $result->add_error("Unknown record type %s", [$type]);
        }
    }
    return $result;
}


=head2 validate_ip($ip_address, $record_type)

Validates that $ip_address is indeed an IP address, and is of the type as you
would expect for $record_type.

Throws an exception if $record_type isn't either "A" or "AAAA"

=cut

sub validate_ip {
    my ( $self, $ip_address, $record_type ) = @_;
    my $result = $self->_new_result;

    # Check that content is an IP address
    my $ip = Net::IP->new($ip_address);
    if ( !$ip ) {
        $result->add_error(
            "Record does not have a valid IP address: %s", [$ip_address]);
    }
    else {
        if ( $record_type eq 'A' && $ip->version == 6 ) {
            $result->add_error('"A" record points to an IPv6 address');
        }
        elsif ( $record_type eq 'AAAA' && $ip->version == 4 ) {
            $result->add_error(
                '"AAAA" record points to an IPv4 address');
        }
        elsif ( !( $ip->version ~~ [qw/4 6/] ) ) {
            croak "How did I get here? Is there a new standard "
              . "of IP that I don't know about?";
        }
        else {
            # Valid request. I'm putting the else here for bookkeeping
            # and to help me understand nested if statements
        }
    }
    return $result;
}

=head2 validate_soa_content($content)

Validates that $content is a valid SOA line, with seven fields:

    $primary, $hostmaster, $serial, $refresh, $retry, $expire, $default_ttl

$content can be either a hashref of the values above (i.e. when the column is inflated)
or a string of the values in the order above (i.e. when the column is deflated)

=cut
sub validate_soa_content {
    my ( $self, $content ) = @_;
    my $result = $self->_new_result;

    my @fields = qw/primary hostmaster serial refresh retry expire default_ttl/;

    my %values;
    if ( ref $content and reftype($content) eq 'HASH' ) {
        @values{@fields} = map { $content->{$_} } @fields;
    }
    elsif ( length( $content ) ) {
        @values{@fields} = split /\s+/, $content;
    }
    else {
        return $result->add_error("Invalid SOA content");
    }

    foreach my $field (@fields) {
        $result->add_error("Missing SOA field %s", [ $field ] )
            if not $values{$field};
    }

    return $result if $result->errors;
    
    $values{primary} =~ /^[a-z.]+$/
      or $result->add_error("Invalid primary %s for SOA", [$values{primary}]);
    $values{hostmaster} =~ /^[a-z.]+$/
      or $result->add_error("Invalid hostmaster %s email for SOA", [$values{hostmaster}]);
    $values{serial} =~ /^\d+$/
      or $result->add_error("Serial %s is not an integer for SOA", [$values{serial}]);
    $values{refresh} =~ /^\d+$/
      or $result->add_error("Refresh %s is not an integer for SOA", [$values{refresh}]);
    $values{retry} =~ /^\d+$/
      or $result->add_error("Retry %s is not an integer for SOA", [$values{retry}]);
    $values{expire} =~ /^\d+$/
      or $result->add_error("Expire %s is not an integer for SOA", [$values{expire}]);
    $values{default_ttl} =~ /^\d+$/
      or $result->add_error("Default TTL %s is not an integer for SOA", [$values{default_ttl}]);
    return $result;
}

=head2 validate_ptr_update

    $validator->validate_ptr_update($record $new_address);

=cut
sub validate_ptr_update {
    my ( $self, $record, $new_address ) = @_;

    my $result = $self->_new_result;
    
    my $ptr_record = $record->reverse_record;
    return $result if not $ptr_record;

    # Must pussy-foot round the scenario where the supplied new IP
    # address is not a valid IP. Should never happen as the validations
    # should have already caught that, but you never know.
    try {
        $record->content($new_address);
        $ptr_record->name( $record->reverse_ip );
    }
    catch {
        $result->shortcircuit('FATAL: Supplied update IP address is not valid for reversing: %s',
            [$_],
            { address => $new_address }
        );
        die "SUUUPER FATAL: Shouldn't ever get here";
    };

    # Validate only if this is a paired record
    if ( $ptr_record ) {

        my $ptr_domain = $ptr_record->update_domain;

        $result->add_error(
            'Cannot update a paired record %s when we do not host the PTR domain',
            [ $record->name ],
            {
                new_address => $new_address,
                arpa_address => $ptr_record->name,
            }
        ) if not $ptr_domain;

    }

    return $result;
}


=head2 validate_ttl_field

Validates that the TTL field is > 300, < 2**32

=cut

sub validate_ttl_field {
    my ( $self, $ttl ) = @_;
    my $result = $self->_new_result;
    
    if ( $ttl !~ /^\d+$/ ) {
        $result->add_error("TTL is not an integer");
    }
    elsif ( $ttl < 300 ) {
        $result->add_error("TTL is too short");
    }
    elsif ( $ttl > 2**32 ) {
        $result->add_error("TTL is too long");
    }
    return $result;
}

=head2 validate_name_field($value, $record_type)

Validates that $value is a valid, RFC1101 compliant DNS name.

=over

=item Length <= 255

=item Number of octets <= 127

=item Each octet's length <= 63

=item $value =~ $RE{net}{domain};

=back

=cut

sub validate_name_field {
    my ( $self, $value, $record_type ) = @_;
    my $result = $self->_new_result;

    # Validate RFC compliance of name
    # http://www.zoneedit.com/doc/rfc/rfc1035.txt
    if ( length $value > 255 ) {
        $result->add_error( "%s is too long a domain name", [$value] );
    }
    my @record_octets = split( /\./, $value );
    foreach my $label (@record_octets) {
        if ( length $label > 63 ) {
            $result->add_error("%s is too long for rfc1035", [$label]);
        }
    }

    $result += $self->validate_ptr_name_field($value)
        if $record_type eq 'PTR';

    return $result if $result->errors;

    if ( scalar @record_octets > 127 ) {
        $result->add_error("Record has too many domain divisors for RFC1035");
    }

    $value =~ /(?! )$RE{net}{domain}/
        or $result->add_error("Record %s is not a valid RFC1101 domain", [$value]);
    return $result;
}

=head validate_ptr_name_field

As L</validate_name_field> does, only is more stringent because of the restrictions
of a valid PTR record name field.

Anyone who looks at the source will see a beast of a regular expression.

=cut

sub validate_ptr_name_field {
    my ( $self, $value ) = @_;
    my $result = $self->_new_result;

    $result->add_error('%s is an invalid PTR name', [ $value ] )
        unless $value =~ m/\A
            # Super beast of a regular expression to match IPv4 PTR record
            (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.in-addr\.arpa
                | # or IPv6
            (?:[0-9a-f]\.){32}ip6\.arpa)
            \z/x;
}

=head2 validate_content_field($value, $record_type)

Helper method to call L</validate_ip>, L</validate_soa_content> or L</validate_parent_record_exists>
on value, depending on $record_type

=cut

sub validate_content_field {
    my ( $self, $value, $type, $schema ) = @_;
    carp "No content supplied" if not $value;

    given ($type) {
        when ( [ 'A', 'AAAA' ] ) {
            return $self->validate_ip($value, $type);
        }
        when ( [ 'SOA' ] ) {
            return $self->validate_soa_content($value);
        }
        default {
            # TODO: Make the type list explicit, don't lazily use "default"
            return $self->validate_parent_record_exists($value);
        }
    }
    die "Shouldn't get here";
}

=head2 validate_parent_record_exists($value)

=over

=item Checks that $value is a record in the current database.

=item Does NOT check external DNS records. That may be something for the future

=back

=cut

sub validate_parent_record_exists {
    my ( $self, $value ) = @_;

    my $result = $self->_new_result;

    my $schema = $self->schema;
    die "Missing schema attribute in object" unless $schema;

 # Check that hostname exists in our database. Tough luck if you want to
 # point to an external DNS.
 #
 # TODO TODO TODO: Fix for external DNS
 #
 # XXX: Does not allow CNAME chaining. I personally don't like CNAME chaining,
 # but if someone feels the need to do this, then go ahead and
 # alter the code to suit.
    if (
        $schema->records->search(
            {
                name => $value,
                type => [ 'A', 'AAAA' ],
            }
        ) == 0
      )
    {
        $result->add_error(
            "Record points to non-existent host %s", [$value] );
    }

    return $result;
}

1;


=head1 BUGS AND LIMITATIONS

There are no known bugs in this module. 
Please report problems to the L</AUTHOR>.
Patches are welcome.
 
=head1 AUTHOR

Christopher Causer <christopher.causer@it.ox.ac.uk>

=head1 LICENSE AND COPYRIGHT
 
 Copyright (c) 2012 Christopher Causer. All rights reserved

 This module is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See L<perlartistic>.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
