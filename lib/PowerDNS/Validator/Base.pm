use utf8;

package PowerDNS::Validator::Base;

use 5.014;

use Carp;
use Hash::AsObject;
use PowerDNS::Validator::Result;

=head1 NAME

 - PowerDNS::Validator::Base;

=head1 SYNOPSIS
 
     use PowerDNS::Validator::Base;

     my $validator = PowerDNS::Validator::Base->new({
     });
     my $validation = $validator->validate_create_record($new_record);
     say 'Found ', scalar $validation->errors, ' errors';
     say 'Found ', scalar $validation->warnings, ' warnings';

     # More accurately
     $validation = $validator->validate_create_record($dbix_row);


     foreach my $error (@{$validation->{errors}}) {
         say $error;
     }
       
=head1 DESCRIPTION

This is the base validator that all validators should inherit from. If you were to include
it in your schema as a validator, it would pass anything that it sees.

=head1 METHODS

=head2 new( \%options )

Create a new Validator object. \%options is available as an accessor

=cut

sub new {
    my ( $class, $options ) = @_;
    my $self = {options => $options};
    return bless $self, ( ref $class || $class );
}

=head2 options

Get back the options (hash) submitted at object instantiation time.

=cut

sub options { shift->{options}; }

=head2 $validator->schema = $schema

Some validations require stateful checks. If you supply this object
with a PowerDNS::DB::Schema object, it will attempt the stateful checks.

This method will return the schema object.

Do not use this method in the normal course of things. It is mainly used internally
by L<PowerDNS::DB::Schema>

=cut

sub schema :lvalue {
    my ( $self ) = @_;
    $self->{_pdns_schema};
}

=head2 assert_has_schema 

Throws a validation error if there is no schema available to do validations

=cut

sub assert_has_schema {
    my ( $self ) = @_;
    my $result = $self->_new_result;
    $result->shortcircuit("FATAL: Missing schema") if not $self->schema;
}

=head2 schema_or_fail 

    $validator->schema_or_fail

Assert that the schema has been given to the validator object and return it.

Dies with a L<PowerDNS::Validator::Result> object

=cut

sub schema_or_fail {
    my ( $self ) = @_;
    $self->assert_has_schema;
    $self->schema;
}

=head2 Methods for overriding

The following methods return a L<PowerDNS::Validator::Result> with
no errors or warnings. They are meant for overriding in child classes

=over

=item validate_create_record( $row, @extra_args)

=item validate_update_record( $row, $updated_columns, @extra_args)

=item validate_delete_record( $row, @extra_args)

=item validate_create_domain( $row, @extra_args)

=item validate_create_domain( $row, $updated_columns, @extra_args)

=item validate_delete_domain( $row, @extra_args)

=back

=cut

#Prototypes for AUTOLOAD to work

use subs qw/
    validate_create_record
    validate_update_record
    validate_delete_record
    validate_create_domain
    validate_update_domain
    validate_delete_domain
/;


sub AUTOLOAD { return __PACKAGE__->_new_result; }

sub _new_result {
    my ( $self ) = @_;
    my $class = ref $self || $self;
    return PowerDNS::Validator::Result->new({
        package => $class,
    });
}

sub _sanitize_row {
    my ( $self, $row ) = @_;
    if ( $row and ref $row ) {
        if ( $row->isa('DBIx::Class::Row') ) { # Is it a DBIx row?
            if ( $row->in_storage ) { # Is it already in the database?
                return $row->get_from_storage;
            }
            else {
                return $row;
            }
        }
    }
    else {
        croak "Row is not acceptable for validation";
    }
    die "Shouldn't get here";
}

sub _separate_clean_from_dirty {
    my ( $self, $dirty_row, $updated_fields ) = @_;

    $updated_fields ||= {};

    croak "Row supplied is not a valid reference: $dirty_row"
        if not ref($dirty_row);

    # Guess that clean row is the same as supplied row unless can
    # ascertain otherwise
    my $clean_row = $dirty_row;

    if ( $dirty_row->isa('DBIx::Class::Row') ) {
        $clean_row = $dirty_row->get_from_storage;
        %$updated_fields = ( $dirty_row->get_dirty_columns, %$updated_fields );
    }
    
    # Objectify the $updated_fields
    $updated_fields = Hash::AsObject->new($updated_fields);

    return ( $clean_row, $updated_fields );
}


=head2 validate_field_presence

   $validator->validate_field_presence($row, \@wanted_fields)

=over

=item Arguments: $row_like_object, \@wanted_fields

=item Return Value: L<$result|PowerDNS::Validator::Result>

=back

Validates that @wanted_fields are present in the $row_like_object.

For example, if $row->ttl is missing, and 'ttl' is in \@wanted_fields, this
method will return a result with an error

=cut

sub validate_field_presence {
    my ( $self, $attributes, $wanted_fields ) = @_;
    my $result = $self->_new_result;

    foreach my $field (@$wanted_fields) {
        if ( ! defined $attributes->$field ) {

            # Special wording for domain_id
            if ( $field eq 'domain_id' ) {
                $result->add_error("Missing domain");
            }
            else {
                $result->add_error("Missing required field '%s'", [$field]);
            }
        }
    }
    return $result;
}

=head2 validate_field_absence

The opposite to L</validate_field_presence>

=cut

sub validate_field_absence {
    my ( $self, $row, $unwanted_fields ) = @_;
    my $result = $self->_new_result;

    foreach my $field (@$unwanted_fields) {
        if ( defined $row->$field ) {
            $result->add_error("Field '%s' is present when it shouldn't be", [$field]);
        }
    }
    return $result;
}

=head2 validate_field_is_unique

=over

=item Arguments: $row, $field, $optional_new_value

=item Return Value: L<PowerDNS::Validator::Result>

=back

Validates that the value of field $field is unique within the database. Can probably make
this a unique key in the database, but the error wouldn't look so nice.

Also, it allows slightly better control. For example, you could validate uniqueness of the 
name field only if the record is a PTR (yes, it is possible to do this using postgresql 
constraints.)

The $optional_new_value is so that if the field is the one being updated, it checks that
rather than the pristine value in storage found in $row.

=cut

sub validate_field_is_unique {
    my ( $self, $row, $field, $value ) = @_;
    my $resultset = $row->result_source->resultset;

    $value ||= $row->$field;

    my $result = $self->_new_result;

    my $existing_rows;
    if ( $row->id ) {
        # Is already a record. We should find at least one.
        $existing_rows = $resultset->search({ $field => $value, id => { '!=' => $row->id }});
    }
    else {
        # Shouldn't see it at all
        $existing_rows = $resultset->search({ $field => $value});
    }
    if ( $existing_rows->count ) {
        return $result->add_error("Row %s field %s is not unique", [ $field, $row->content ]);
    }
    else {
        return $result;
    }
}
        
1;

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to the L</AUTHOR>.
Patches are welcome.
 
=head1 AUTHOR

Christopher Causer <christopher.causer@it.ox.ac.uk>

=head1 LICENSE AND COPYRIGHT
 
 Copyright (c) 2013 Christopher Causer. All rights reserved

 This module is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See L<perlartistic>.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
