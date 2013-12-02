use utf8;
package PowerDNS::DB::Result::Supermaster;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PowerDNS::DB::Result::Supermaster

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

=head1 TABLE: C<supermasters>

=cut

__PACKAGE__->table("supermasters");

=head1 ACCESSORS

=head2 ip

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 nameserver

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 account

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 40

=cut

__PACKAGE__->add_columns(
  "ip",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "nameserver",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "account",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 40,
  },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-31 10:30:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yIc4Fpih6wWEWuQ2UMeFOQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
