package PowerDNS::DB::ResultSet::Domain;
use parent 'DBIx::Class::ResultSet';
use Data::Dumper;

use strict;
use warnings;

=head1 NAME

PowerDNS::DB::ResultSet::Domain - ResultSet methods for Domain objects

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is responsible for overriding ResultSet operations on PowerDNS
domain rows. It is a child of L<DBIx::Class:ResultSet> and inherits most
methods directly from that.

Methods here override some key methods used by DBIx. For the most part,
they are for validation, but there are some instances where datasets are
changed and implicit updates are done. See the method descriptions themselves
for further details

=cut

=head1 METHODS


=head2 update

Currently not implemented and throws an exception.

=cut

sub update {
    shift->throw_exception("Not implemented yet");
}

=head2 new_result

=over

=item Arguments, \%columns?, \%extra_parameters?

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

The same as a normal ResultSet new_result, except that it has \%extra_parameters
which is passed to the new $row, and you can supply a "soa" key in the \%columns hash,
which is changed into a fully fledged SOA record.

=cut


sub new_result {
    my ( $self, $columns, $extra_parameters ) = @_;
    my $soa_fields = $columns->{soa};
    delete $columns->{soa};
    my $domain = $self->next::method($columns);
    $soa_fields->{domain} = $domain;
    $soa_fields->{name} ||= $domain->name;
    $soa_fields->{type} = 'SOA';
    my $soa_record = $self->schema->records->new_result($soa_fields);
    $domain->soa_record = $soa_record;
    return $domain;
}


=head2 $resultset->schema

Convenience method to get the schema for the resultset
=cut

sub schema { shift->result_source->schema; }

1;
