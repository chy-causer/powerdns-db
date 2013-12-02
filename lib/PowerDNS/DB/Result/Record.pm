use utf8;
package PowerDNS::DB::Result::Record;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PowerDNS::DB::Result::Record

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<records>

=cut

__PACKAGE__->table("records");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'records_id_seq'

=head2 domain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 name

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 255

=head2 type

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 10

=head2 content

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 255

=head2 ttl

  data_type: 'integer'
  is_nullable: 1

=head2 prio

  data_type: 'integer'
  is_nullable: 1

=head2 change_date

  data_type: 'integer'
  is_nullable: 1

=head2 ordername

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 auth

  data_type: 'boolean'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "records_id_seq",
  },
  "domain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
  "type",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 10,
  },
  "content",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
  "ttl",
  { data_type => "integer", is_nullable => 1 },
  "prio",
  { data_type => "integer", is_nullable => 1 },
  "change_date",
  { data_type => "integer", is_nullable => 1 },
  "ordername",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "auth",
  { data_type => "boolean", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 domain

Type: belongs_to

Related object: L<PowerDNS::DB::Result::Domain>

=cut

__PACKAGE__->belongs_to(
  "domain",
  "PowerDNS::DB::Result::Domain",
  { id => "domain_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-31 10:30:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M3hmTRTuzeFtYDVDPMfKvQ


# CC Added outside of DBIx::Class::Schema::Loader
#
use 5.014;
use Try::Tiny;
use Net::IP;

__PACKAGE__->load_components('+PowerDNS::DB::Row::Record');

=head2 Inflated columns

=over 

=item content

Inflated when the record is an SOA record. Inflates it to a hashref with
keys primary, hostmaster, serial, refresh, retry, expire and default_ttl.

=back

=cut

__PACKAGE__->inflate_column('content', {
        inflate => sub {
            my ( $raw_value_from_db, $result_object ) = @_;
            given ( $result_object->type ) {
                when ('SOA') { inflate_soa($raw_value_from_db);}
                default { $raw_value_from_db }
            }
        },
        deflate => sub {
            my ( $inflated_value, $result_object ) = @_;
            given ( $result_object->type )  {
                when ('SOA') { deflate_soa($inflated_value);}
                when ([qw[A AAAA]]) { Net::IP->new($inflated_value)->ip;}
                default { "$inflated_value"; }
            }
        }
});


=head2 inflate_soa
=cut
sub inflate_soa {
    my ( $string ) = @_;
    my %inflated_soa;

    # Bet you never knew perl could do this!
    @inflated_soa{qw/primary hostmaster serial refresh retry expire default_ttl/} = split(/\s+/, $string);
    return \%inflated_soa;
}

=head2 deflate_soa
=cut
sub deflate_soa {
    my %inflated_soa = %{$_[0]};
    return join(' ', @inflated_soa{qw/primary hostmaster serial refresh retry expire default_ttl/});
}

1;
