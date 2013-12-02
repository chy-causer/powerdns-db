use utf8;
package PowerDNS::DB::Result::Domainmetadata;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PowerDNS::DB::Result::Domainmetadata

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

=head1 TABLE: C<domainmetadata>

=cut

__PACKAGE__->table("domainmetadata");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'domainmetadata_id_seq'

=head2 domain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 kind

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 content

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "domainmetadata_id_seq",
  },
  "domain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "kind",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "content",
  { data_type => "text", is_nullable => 1 },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MzGryqG9qL16yoDZGIz5AA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
