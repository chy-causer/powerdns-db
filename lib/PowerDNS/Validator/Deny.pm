package PowerDNS::Validator::Deny;
use v5.14;    # We want all the trimmings available to us

sub new {
    my ( $class, $options ) = @_;
    my $self = {};
    my $self->{message} = $options->{message}
      || 'Denied by PowerDNS::Validator::Deny';
    return bless $self, ( ref $class || $class );
}

sub validate {
    my ($self) = @_;
    my $result = PowerDNS::Validator::Result->new();
    return $result->add_error( $self->{message} );
}

1;

=head1 NAME

 - PowerDNS::Validator::Deny;

=head1 VERSION

See L<PowerDNS::DB>

=head1 SYNOPSIS
 
     use PowerDNS::Validator::Deny;

     my $validator = PowerDNS::Validator::Deny->new({
         message => "No stairway? Denied!",
     });

     print $validator->validate('create record', $fields)->errors[0];
     # ==> "No stairway? Denied!";
       
=head1 DESCRIPTION

This validator will disallow any action sent to PowerDNS. It is useful for testing
and debugging purposes. When used in testing, try doing it like this:

    use PowerDNS::DB;

    my $pdns = PowerDNS::DB->new(\%options);

    $pdns->add_validator($validator); # From above

    $pdns->records->create(\%fields);

    my $errors = $pdns->last_validation->errors;

=head1 METHODS

=head2 new(\%options)

Returns a PowerDNS::Validator::Deny object

=head3 options

=over 4

=item message

Specify what message you want for your denial

=back

=head2 validate

Always returns a PowerDNS::Validator::Result object which has one error. The error message
is customizable in L</new>


=head1 DIAGNOSTICS



=head1 CONFIGURATION AND ENVIRONMENT



=head1 DEPENDENCIES



=head1 INCOMPATIBILITIES



=head1 BUGS AND LIMITATIONS

There are no known bugs in this module. 
Please report problems to the L</AUTHOR>
Patches are welcome.
 
=head1 AUTHOR

Christopher Causer <christopher.causer@it.ox.ac.uk>

=head1 LICENSE AND COPYRIGHT
 
 Copyright (c) 2012 Oxford University IT Services. All rights reserved

 This module is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See L<perlartistic>.
  
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

