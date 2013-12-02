package PowerDNS::Validator::Result;

use 5.014;    # So that push can accept refs
use strict;
use warnings;
use Carp;
use Scalar::Util qw/refaddr/;
use Data::Dumper;
use overload q("") => \&as_string,
             '='  => sub { shift }, # Copy Constructor ProgPerl 4th Ed pp468. Don't want to clone it.
             'cmp' => sub { shift->as_string cmp shift }, # A requirement of DBIx::Class::Storage::BlockRunner. Dies are cmp'd with '' for some reason.
             "+=" => \&add_result,
             "+" => \&sum_result;

=head1 NAME

 - PowerDNS::Validator::Result;

=head1 VERSION

This module is bundled with L<PowerDNS::DB>. Please see that
module for version numbers

=head1 SYNOPSIS
 
    package PowerDNS::Validator::MyValidator;

    use parent PowerDNS::Validator::Base;
    use PowerDNS::Validator::Result;

    sub validate {
        my ( $self, $action, @extra_arguments ) = @_;
        my $validation_result = PowerDNS::Validator::Result->new;
        $validation_result->add_error("Computer says no");
        return $validation_result;
    }
  
=head1 DESCRIPTION

When writing a Validator for the PowerDNS::DB interface, all objects returned
must be a PowerDNS::Validator::Result object. It contains some useful methods
for accessing and managing validation errors

=head1 METHODS

=head2 Overloaded methods

=over

=item qw("") => L</as_string>

=item += => L</add_result>

=item + => L</sum_result>

=back



=cut

=head2 new(\%options)

Returns a PowerDNS::Validator::Result object. The hash %options is as yet unused
by this module.

=cut

sub new {
    my ( $class, $options ) = @_;
    my $validating_package = $options->{package} || 'Unknown validator';
    my $self = {
        warnings => [],
        errors   => [],
        _current_validating_package => "$validating_package",
    };
    return bless $self, ( ref $class || $class );
}

=head2 add_error

   $result->add_error("Cannot %s without a %s", "validate", "schema");

=over

=item Arguments: $error_string, @variables used for interpolation

=item Return Value: $self

=back

Add an error to the result. The method itself does some voodoo to add some
useful debug information which can be viewed using $result->debug

Add a warning or an error to the list of errors or warnings returned. Returns $self,
which is handy. It means you can do this.

    if ($SERIOUS_ERROR) {
        return $validation_result->add_error($SERIOUS_ERROR_STRING);
    }

and PowerDNS::DB will do the rest (or not, since it's just failed its validation.)


=cut

sub add_error {
    my ( $self, $error, $variables, $extra_details ) = @_;
    $self->_append('errors', $error, $variables, $extra_details);
    return $self;
}

=head2 add_warning

Same as add_error, only adds a warning instead of an error.

=cut

sub add_warning {
    my ( $self, $warning, $variables, $extra_details ) = @_;
    $self->_append('warnings', $warning, $variables, $extra_details);
    return $self;
}

=head2 shortcircuit

    $result->shortcircuit("Cannot let you do that %d", [qw/dave/]);

=over

=item Arguments, $error_string, \@interpolated_values_for_string, \%extra_details

=item Return Value: No return, just dies.

=back

Validators are processed linearly. If an error is so bad no further validation
is possible, then just shortcircuit the validation process.

This method behaves the same as L</add_error>, except it  will issue a die
with $self as the die argument rather than returning $self.

=cut

sub shortcircuit {
    my ( $self, $error, $variables, $extra_details ) = @_;
    $self->_append('errors', $error, $variables, $extra_details) if $error;
    die $self;
}

=head2 die

Synonym for shortcircuit, only does not take any arguments, it just dies 
with $self as the died reference.

=cut

sub die { shift->shortcircuit; }

=head2 die_if_errors

Like die, only dies if there are validation errors. Returns $self otherwise.

=cut

sub die_if_errors {
    my ( $self ) = @_;
    $self->die if $self->errors;
}

=head2 add_result

=over

=item Arguments $validation_result_object

=item Return Value: $self

=back

When you have two $validation_result objects, this will merge the two together. Be warned
that this method is not symmetric; The second object is slurped into the first object, so always
retain the first object and disregard the latter.

In other words

    $cumulative_results->add_result($result_from_earlier);
    $cumulative_results->add_result($result_from_a_bit_after_result_from_earlier);
    return $cumulative_results;

=cut

sub add_result {
    my ( $self, $validation_result ) = @_;

    return if not $validation_result;
    confess "Invalid result class"
        unless $validation_result->isa('PowerDNS::Validator::Result');

    #TODO: Check uniqueness
    croak "Cannot merge two results if they are the same"
      if refaddr($self) == refaddr($validation_result);

    push @{$self->{errors}},   @{$validation_result->{errors}};
    push @{$self->{warnings}}, @{$validation_result->{warnings}};
    return $self;
}

=head2 sum_result

As L<add_result> above, only returns a new object instead of adding the
result to $self

=cut

sub sum_result {
    my ( $self, $validation_result ) = @_;
    return if not $validation_result;

    croak "Cannot sum two results if they are the same"
      if refaddr($self) == refaddr($validation_result);

    my $new_result = $self->new;
    $new_result += $self;
    $new_result += $validation_result;
    return $new_result;
}

=head2 errors

=over

=item Arguments: none

=item Return Value: list of hashrefs containing errors

=back

Return errors in the validation result.
This method can be used for its boolean context:

    if ($validation_result->errors) {
        print "AWWWWWOOOOOOOGA";
    }

=cut

sub errors {
    my ($self) = @_;
    return map {$self->_stringify_message($_)} @{ $self->{errors} };
}

=head2 warnings

=over

=item Arguments: none

=item Return Value: list of warning strings

=back

Return warnings in the validation result

=cut
sub warnings {
    my ($self) = @_;
    return map {$self->_stringify_message($_)} @{ $self->{warnings} };
}

=head2 as_string

Returns the validation_result object as a string representation
which is good for printing to a terminal

=cut

sub as_string {
    my ( $self ) = @_;

    my $rtn = '';

    #Stringify errors
    if ( $self->errors ) {
        $rtn .= "  Errors returned: \n\t  -- "
          . join( "\n\t  -- ", $self->errors) . "\n";
    }
    else {
        $rtn .= "  No errors returned\n";
    }

    #Stringify warnings
    if ( $self->warnings ) {
        $rtn .= "  Warnings returned: \n\t  -- "
          . join( "\n\t  -- ", $self->warnings) . "\n";
    }
    else {
        $rtn .= "  No warnings returned\n";
    }
    return $rtn;
}

=head2 debug

Alter debug. For internal use only

=cut

sub debug :lvalue {
    my ( $self ) = @_;
    $self->{_debug};
}

sub _append {
    my ( $self, $message_list, $message, $variables, $extra_details ) = @_;

    my ( $package, $filename, $line, $subroutine ) = caller 2;

    $variables ||= [];
    $extra_details ||= {};

    push @{$self->{$message_list}}, {
        string => $message,
        variables => $variables,
        package => $self->{_current_validating_package},
        subroutine => $subroutine,
        detail => $extra_details,
        debug => $self->debug, # For when it goes out of scope
    };
    return $self;
}

# TODO: Translation? 
sub _stringify_message {
    my ( $self, $warning_or_error ) = @_;
    return sprintf($warning_or_error->{string},
        @{$warning_or_error->{variables}});
}

1;

=head1 DIAGNOSTICS



=head1 CONFIGURATION AND ENVIRONMENT



=head1 DEPENDENCIES



=head1 INCOMPATIBILITIES



=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.
Please report problems to Christopher Causer <christopher.causer@it.ox.ac.uk>
Patches are welcome.
 
=head1 AUTHOR

Christopher Causer <christopher.causer@it.ox.ac.uk>

=head1 LICENSE AND COPYRIGHT
 
Copyright (c) 2013 Christopher Causer (<christopher.causer@it.ox.ac.uk>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

