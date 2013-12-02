package PowerDNS::DB::Row::Record;

use strict;
use warnings;

use parent qw(DBIx::Class);
use Data::Dumper;
use Carp;
use Net::IP;
use 5.014;

=head1 NAME

PowerDNS::DB::Row::Record - Row methods for Record objects

=head1 SYNOPSIS

=head1 DESCRIPTION

This class is responsible for row level operations on PowerDNS
record rows. It is derived from L<DBIx::Class::ResultSource> objects.

Methods here override some key methods used by DBIx. For the most part,
they are for validation, but there are some instances where datasets are
changed and implicit updates are done. See the method descriptions themselves
for further details

=head1 METHODS

=head2 insert(\%extra_parameters)

    my $row->insert({create_ptr => 1});
    my $row->insert();

=over

=item Arguments: hashref

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

Eventually calls L<DBIx::Class::Row> but does a few extra things before
that

=over

=item Validation

=item Creates a reverse PTR record if create_ptr is true in \%extra_parameters

=back

=cut

sub insert {
    my ( $self, $extra_parameters ) = @_;
    $extra_parameters ||= {};

    my $validation =
      $self->_schema->validate( 'create record',
        $self, $extra_parameters );
    $validation->die_if_errors;

    $self->sanitize_fields;

    $self->_schema->txn_do( sub{
        if ( not $extra_parameters->{dry_run} ) {
            return $self->next::method();
        }
        if ( $self->reverse_record ) {
            $self->reverse_record->insert($extra_parameters);
        }

    });
}

sub sanitize_fields {
    my ( $self ) = @_;
    given ( $self->type ) {
        when ([qw[A AAAA]]) {
            # Leave it to validations to see if it is a valid content or not.
            eval {
                $self->content = Net::IP->new($self->content)->ip;
            };
        }
    }
}

sub delete {
    my ( $self, $extra_parameters ) = @_;

    #TODO: validation;

    # Cascade deletions
    foreach my $record ( $self->dependent_records ) {
        $record->delete;
    }
    $self->next::method();
}

=head2 update(\%columns, \%extra_parameters)

=over

=item Arguments: none or a hashref

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

Validates the updated columns (columns as defined in \%columns and those
marked as dirty by DBIx) and updates any PTR records if the content of an
A or AAAA record changes.

Throws an exception if it cannot update the PTR record

=cut

sub update {
    my ( $self, $columns, $extra_parameters ) = @_;


    $columns ||= {};

    # Not strictly necessary now that the validator separates
    # dirty from clean columns, but keeping the code here, more
    # for this comment than anything else
    #
    my %updated_columns = $self->get_dirty_columns;
    foreach my $key ( keys %$columns ) {
        $updated_columns{$key} = $columns->{$key};
    }

    # Validate
    my $validation = $self->_schema->validate( 'update record',
        $self, \%updated_columns, $extra_parameters );

    $self->throw_exception($validation)
        if $validation->errors;

    # Update PTR record if required
    my $new_content = $columns->{content} || $self->content;
    my $pristine_record = $self->get_from_storage;
    if ( $self->type ~~ [qw/A AAAA/] and $pristine_record->content ne $new_content ) {
        if ( my $ptr_record = $pristine_record->reverse_record ) {
            # TODO: allow reverse_ip to work with arguments
            $self->content($new_content);
            $ptr_record->name($self->reverse_ip);
            my $ptr_domain = $ptr_record->update_domain;

            $ptr_record->update;

            $self->reverse_record('recache');
        }
    }
    return $self->next::method($columns)
        if $validation->errors;

    $self->_schema->txn_do( sub {

        # Update PTR record if required
        my $new_content = $columns->{content} || $self->content;
        my $pristine_record = $self->get_from_storage;
        if ( $self->type ~~ [qw/A AAAA/] and $pristine_record->content ne $new_content ) {
            if ( my $ptr_record = $pristine_record->reverse_record ) {
                # TODO: allow reverse_ip to work with arguments
                $self->content($new_content);
                $ptr_record->name($self->reverse_ip);
                my $ptr_domain = $ptr_record->update_domain;

                $ptr_record->update;

                $self->reverse_record('recache');
            }
        }
        return $self->next::method($columns);
    });
}

=head2 copy

Throws an exception

=cut

sub copy { shift->throw_exception("Not implemented"); }

=head2 reverse_record($boolean)

   my $reverse_record = $row->reverse_record;

=over

=item Arguments: $boolean

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass> or undef

=back

If the record is an A or AAAA record, retrieves a PTR record that is
the reverse equivalent of this. Only returns one record, so if you
are one of those perverse organisations with round robin PTR records,
I'm afraid you are out of luck here.

Returns undef if $row is not an A or AAAA record.

Returns undef if PTR record does not exist for A or AAAA record

=cut

sub reverse_record {
    my ( $self, $recache ) = @_;

    if ( $recache or not exists $self->{_pdns_reverse_record} ) {

        # Not an A or AAAA record
        return
          if not $self->type ~~ [qw(A AAAA PTR)];

        # Not yet in database
        $self->throw_exception("Record has not been saved yet")
          if not $self->in_storage;

        # Different logic depending on record type
        given ( $self->type ) {
            when ( [ qw[A AAAA] ] ) {

                my $reverse_ip         = eval { $self->reverse_ip} ;
                $self->throw_exception(
                    sprintf( "Record %s is not an IP when it should be", $self->id ) )
                  if not $reverse_ip;

                $self->{_pdns_reverse_record} = $self->result_source->resultset->find(
                    {
                        type    => 'PTR',
                        content => $self->name,
                        name    => $reverse_ip,
                    }
                );
            }
            when ( [ qw[PTR] ] ) {

                # Check type of PTR

                my ( $reverse_type, $ip_address );
                if ( $self->name =~ /in-addr\.arpa\Z/ ) {
                    $reverse_type = 'A';
                    # IP address is the PTR name, with the ending lopped off, split on '.', 
                    # reversed, then rejoined.
                    ( $ip_address = $self->name ) =~ s/\.in-addr\.arpa\Z//;
                    $ip_address = join '.', reverse split /\./, $ip_address;

                }
                elsif ( $self->name =~ /ip6\.arpa\Z/ ) {
                    $reverse_type = 'AAAA';
                    ( $ip_address = $self->name ) =~ s/ip6\.arpa\Z//;
                    my @bytes = $ip_address =~ m/((?:[0-9a-f]\.){4})/g;
                    $ip_address = join ':', reverse map { join '', reverse split /\./ } @bytes;
                }
                else {
                    croak "Invalid name for PTR record:" . $self->name;
                }

                $self->{_pdns_reverse_record} = 
                    $self->result_source->resultset->search_ip($ip_address);
            }
        }
    }
    return $self->{_pdns_reverse_record};
}

=head2 type_with_details

  $a_record->type_with_details eq 'A [REVERSED]';

=over

=item Arguments: None

=item Return Values: String

=back

As the type column would return, except if the record is an A/AAAA record, and has a corresponding
PTR record. In this case, 'A [REVERSED]' or 'AAAA [REVERSED]' are returned.

=cut

sub type_with_details {
    my ( $self ) = @_;
    given ( $self->type ) {
        when ( [ qw[A AAAA PTR] ] ) {
            if ( $self->reverse_record ) {
                return $self->type . " [PAIRED]";
            }
        }
    }
    return $self->type;
}


sub create_reverse_record {
    my ( $self ) = @_;
    $self->throw_exception("Cannot create PTR for this record")
        unless $self->type ~~ [qw[A AAAA]];

    my $ptr_record = $self->result_source->resultset->new_result(
        {
            type    => 'PTR',
            name    => $self->reverse_ip,
            content => $self->name,
            ttl     => $self->ttl,
        }
    );
    $ptr_record->update_domain;
    $self->{_pdns_reverse_record} = $ptr_record;
}


=head2 dependent_records

=over

=item Arguments: none

=item Return value. $resultset or @rows

=back

Get the records whose content is the same as the row's name. Does not return PTR records.

=cut

sub dependent_records {
    my ( $self ) = @_;
    return $self->_schema->records->search( {
            content => $self->name,
            type => { '!=' => 'PTR' },
    });
}

=head2 reverse_ip

=over

=item Arguments: none

=item Return Value: Reverse IP as a string

=back

While you would normally be happy with Net::IP::ip_reverse, I couldn't
get it to work properly using the procedural interface and IPv6. Also,
the function adds a trailing dot, which is not what PowerDNS expects.

The following will evaluate to true:

   $row->content eq '192.168.56.2';
   $row->reverse_ip eq '2.56.168.192.in-addr.arpa';

=cut

sub reverse_ip {
    my ( $self ) = @_;
    $self->throw_exception("Invalid record type")
      unless $self->type ~~ [qw/A AAAA/];

    # Beware: The functional version of reverse_ip does
    # very weird things with IPv6 addresses. Probably a bug
    # but didn't have the energy to investigate fully when
    # the OO method works fine.
    my $ip = Net::IP->new( $self->content );
    $self->throw_exception(sprintf(
            "Record %s is not an IP when it should be",
            $self->id
        ) ) if not $ip;

    my $ptr_name = $ip->reverse_ip;

    # PowerDNS strips trailing dots.
    $ptr_name =~ s/\.$//;
    return $ptr_name;
}


=head2 parent_records

    my $resultset = $row->parent_records;
    my @rows = $row->parent_records;

=over

=item Arguments: none

=item Return Value: L<$resultset|DBIx::Class::Resultset> or a list of L<$rows|DBIx::Class::Manual::ResultClass>

=back

If a record is a derived record (i.e. not A nor AAAA), then this record
will retrieve the records upon which this $row depends.

Returns a resultset or list of rows, depending on context.

Throws an error if $row is an A or AAAA record.

Please note that this method is not psychic. It does not know of any records external to the database which
the record is pointing to.

=cut

sub parent_records {
    my ($self) = @_;

    $self->throw_exception("parent_record does not work for A and AAAA records")
      if $self->type ~~ [qw[A AAAA]];

    return $self->result_source->resultset->search(
        {
            type => [qw[A AAAA]],
            name => $self->content,
        }
    );
}

=head2 update_domain

    my $domain = $row->update_domain

    #or

    $row->update_domain

=over

=item Arguments: none

=item Return Value: L<PowerDNS::DB::Schema::Result::Domain> or undef

=back

Guess what the domain of a record should be, based on what its name field is.

It completely ignores the domain_id foreign key reference and is good for new
records or PTR records that have had their name field changed.
=cut

sub update_domain {
    my ( $self ) = @_;

    my $domain_name = $self->name
      or $self->throw_exception("Cannot guess domain of an anonymous record");

    my $domain_rs = $self->_schema->domains;

    while ( $domain_name =~ s/^[^.]+\.// ) {

        # XXX: Could be much faster here, but this is a relatively
        # unused method

        if ( my $domain = $domain_rs->find( { name => $domain_name } ) ) {
            $self->domain_id($domain->id);
            return $domain;
        }
    }
    $self->domain_id(undef);
    return;
}

=head2 hostname([$hostname])

  $row->name eq 'wibble.example.org';
  $row->hostname eq 'wibble';

Gets or sets the hostname of a record, i.e. without the domain

=over

=item Arguments: optional $hostname

=item Return Value: String

=back

=cut

sub hostname  {
    my ( $self, $hostname ) = @_;
    if ( $hostname ) {
        $self->name($hostname . $self->domain->name);
    }
    return $self->name =~ s/\..+$//r;
}


# Helper method to get the schema for a row.
sub _schema { shift->result_source->schema; }

1;
