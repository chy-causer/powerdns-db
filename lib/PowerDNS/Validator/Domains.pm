package PowerDNS::Validator::Domains;
use 5.014;    # We want all the trimmings available to us
use strict;
use warnings;
use Data::Dumper;
use PowerDNS::Validator::Records;
use Carp;

use parent qw(PowerDNS::Validator::Base);

use PowerDNS::Validator::Result;

=head1 NAME

 - PowerDNS::Validator::Domains;


=head1 SYNOPSIS
 
     use PowerDNS::Validator::Domains;

     $schema->add_validator(PoerDNS::Validator::Domains->new);
     $schema->validate('create domain', $row, $extra_parameters);
       
     print $schema->last_validation;

=head2 DESCRIPTION

Provides the validations for domain based actions. See L<PowerDNS::Validations::Basic>
on how this fits together

=head1 METHODS

=head2 validate_create_domain

=over

=item Arguments: $row_like_object

=item Return Value: <$result|PowerDNS::Validator::Result>

=back

Provides the following validations

=over

=item Uniqueness of $row->name

=item Presence of $row->name

=back

=cut

sub validate_create_domain {
    my ( $self, $row ) = @_;

    my $result = $self->_new_result;
    $row = $self->_sanitize_row($row);

    $result += $self->validate_field_presence($row, [qw/name/]);
    return $result if $result->errors;

    my $record_validator = PowerDNS::Validators::Records->new;
    $result += $record_validator->validate_create_record($row->soa_record);

    if ($row->result_source->schema) {
        if ( $row->result_source->schema->domains->search({
                    name => $row->name
            })->count ) {
            return $result->add_error("Domain %s exists", [$row->name]);
        }
    }
    return $result;
}

=head2 validate_update_domain

Currently raises a "Validation not implemented" exception

=cut

sub validate_update_domain { shift->_new_result->shortcircuit("Validation Not implemented"); }

=head2 validate_delete_domain

Currently raises a "Validation not implemented" exception

=cut

sub validate_delete_domain { shift->_new_result->shortcircuit("Validation Not implemented"); }

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
