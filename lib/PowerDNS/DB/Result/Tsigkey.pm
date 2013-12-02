use utf8;
package PowerDNS::DB::Result::Tsigkey;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PowerDNS::DB::Result::Tsigkey

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

=head1 TABLE: C<tsigkeys>

=cut

__PACKAGE__->table("tsigkeys");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tsigkeys_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 algorithm

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 secret

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tsigkeys_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "algorithm",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "secret",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<namealgoindex>

=over 4

=item * L</name>

=item * L</algorithm>

=back

=cut

__PACKAGE__->add_unique_constraint("namealgoindex", ["name", "algorithm"]);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-31 10:30:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bP5avPPYHjEGaP6IF93zcg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
