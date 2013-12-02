use utf8;
package PowerDNS::DB::Result::Domain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PowerDNS::DB::Result::Domain

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

=head1 TABLE: C<domains>

=cut

__PACKAGE__->table("domains");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'domains_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 master

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 20

=head2 last_check

  data_type: 'integer'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 6

=head2 notified_serial

  data_type: 'integer'
  is_nullable: 1

=head2 account

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 40

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "domains_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "master",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 20,
  },
  "last_check",
  { data_type => "integer", is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 6 },
  "notified_serial",
  { data_type => "integer", is_nullable => 1 },
  "account",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 40,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_index>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_index", ["name"]);

=head1 RELATIONS

=head2 cryptokeys

Type: has_many

Related object: L<PowerDNS::DB::Result::Cryptokey>

=cut

__PACKAGE__->has_many(
  "cryptokeys",
  "PowerDNS::DB::Result::Cryptokey",
  { "foreign.domain_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 domainmetadatas

Type: has_many

Related object: L<PowerDNS::DB::Result::Domainmetadata>

=cut

__PACKAGE__->has_many(
  "domainmetadatas",
  "PowerDNS::DB::Result::Domainmetadata",
  { "foreign.domain_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 records

Type: has_many

Related object: L<PowerDNS::DB::Result::Record>

=cut

__PACKAGE__->has_many(
  "records",
  "PowerDNS::DB::Result::Record",
  { "foreign.domain_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-31 10:30:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AdqKNaG13nKXl5ph5Ru9pQ

# Added outside of DBIx::Class::Schema::Loader
__PACKAGE__->load_components('+PowerDNS::DB::Row::Domain');
1;
