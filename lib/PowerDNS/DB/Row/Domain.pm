package PowerDNS::DB::Row::Domain;

use strict;
use warnings;

use Data::Dumper;
use PowerDNS::Validator::Result;
use Carp;
use Scalar::Util qw/refaddr/;

use parent qw(DBIx::Class);

=head1 NAME

PowerDNS::DB::Row::Domain - Row methods for Domain objects

=head1 SYNOPSIS

Treat as you would any DBIx:Class row object

=head1 DESCRIPTION

This class is responsible for row level operations on L<PowerDNS:DB>
domain rows. It is derived from L<DBIx::Class::ResultSource> objects.

Methods here override some key methods used by DBIx. For the most part,
they are for validation, but there are some instances where datasets are
changed and implicit updates are done. See the method descriptions themselves
for further details

=head1 METHODS

=head2 insert(\%extra_parameters)

    my $row->insert();

=over

=item Arguments: hashref

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

Eventually calls L<DBIx::Class::Row> but does a few extra things before
that

=over

=item Validation

=item Creates an SOA record from $row->soa_record.

=back

=cut

sub insert {
    my ( $self, $extra_parameters ) = @_;

    my $validation = $self->result_source->schema->validate( 'create domain', $self, $extra_parameters );

    if ( not $validation->errors ) {
        my $domain = eval {$self->next::method()};
        $self->result_source->schema->no_validations_do(sub {
            $self->soa_record->insert;
        });
        return $domain;
    }
    return;
}

=head2 update

Throws a now implemented exception

=cut
sub update {
    my ( $self, $columns, $extra_parameters ) = @_;

    $self->throw_error("Not implemented\n");
}

=head2 save

Throws a not implemented exception

=cut

sub save {
    my ( $self, $extra_parameters );

    $self->throw_error("Not implemented\n");
}

=head2 soa_record($bool) :lvalue

   my $soa_record = $domain->soa_record;

=over

=item Arguments:$recache

=item Return Value: $record

=back

Returns the SOA record for a domain. Behind the scenes, some caching is done.
If you want a fresh SOA record retrieved from the database, then pass a true value
to the method.

=cut


sub soa_record :lvalue {
    my  ( $self, $recache ) = @_;
    if ( $self->id and ( not $self->{_pdns_soa_record} or $recache ) ) {
        $self->{_pdns_soa_record} =
            $self->result_source->schema->records->search({
                type => 'SOA',
                domain_id => $self->id,
            })->first;
    }
    $self->{_pdns_soa_record};
}

1;
__END__

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

