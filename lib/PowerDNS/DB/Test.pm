package PowerDNS::DB::Test;

use parent 'PowerDNS::DB';
use strict;
use warnings;

use DBI;


# Collect schema info from the DATA section of this file, and store it should
# anyone want it for multiple resets
our @SCHEMA;
{
    local $/ = "\;\n";
    while (<DATA>) { push @SCHEMA, $_ }
}


=head1 NAME

PowerDNS::DB::Test - Subclass of L<PowerDNS::DB>, used for testing.

=head1 SYNOPSIS

    use PowerDNS::DB::Test;
    my $db = PowerDNS::DB::Test->new;
    
    # No need to create fixture data, it's done for you
    $db->records->all();

    # Can create records etc.
    $db->records->create(\%new_record_data);

    # Can wipe the slate clean and start again
    $db->reset;

=head1 DESCRIPTION

A convenience module to test PowerDNS::DB. It contains all methods from that
module, as well as L</reset>. The database is stored in memory and is cleared at
the end of the test session, and the database is immediately populated with
fixture data.

=head1 METHODS

=head2 new

As L<PowerDNS::DB/connect>, only you need not worry about any connection, or any schema.
This just creates a database in memory along with a few records, for you to
test your module which hangs off PowerDNS::DB

However, you can supply it a hashref with one key, dsn. This key will be used
for creating a (probably SQLite) db connection. This is useful if you want to populate
your own database for testing

=cut

#TODO: Supplied dsn is not yet checked to see if it is a valid sqlite dsn
sub new {
    my $class = shift;
    my ( $args )  = @_;

    $class = ref $class || $class;

    $args->{dsn} ||= 'dbi:SQLite:dbname=:memory:';

    # Line below is ugly. It is tricking _new_database into thinking
    # an unblessed hashref is $self. Still, it works.
    my $dbh = _new_database({
            dsn => $args->{dsn}
    });

    my $self = bless PowerDNS::DB->connect( sub { $dbh } ), $class;

    $self->{dsn} = $args->{dsn};
    $self->{dbh} = $dbh;

    $self->_create_tables;
    $self->_populate_db;

    return $self;
}

=head2 connect

Alias for L</new>

=cut

sub connect { new(@_) };

sub _create_tables {
    my ($self) = @_;
    foreach my $line (@SCHEMA) {
        $self->{dbh}->do($line);
    }
}

sub _new_database {
    my ( $self ) = @_;
    $self->{dbh} = DBI::->connect(  $self->{dsn}, undef, undef, { RaiseError => 1 } );
    return $self->{dbh};
}

=head2 reset

When you are testing, sometimes you want to reset to an untouched database.
This is the method for you.

    $pdns->records->$MAKE_LOADS_OF_CHANGES(@ARGS);
    $pdns->reset;

( Technically this isn't resetting the database, this is creating a whole new database
and returning that instead. The old database should go up in a puff of smoke at the next
GC, but that is an implementation detail that you probaby do not need to know about. )
=cut

sub reset {
    my ( $self ) = @_;

    $self->_new_database;
    $self->connection( sub { $self->{dbh} } );
    $self->_create_tables;
    $self->_populate_db;
}


=head2 _populate_db

This populates the database which fixture data. This cannot use any methods in PowerDNS::DB
because obviously that could be something we want to test!

Make doubly doubly (i.e. quadrupally) sure that the records are all above board because
we do not want to test using faulty fixture data.
=cut

sub _populate_db {
    my ($self) = @_;
    $self->no_validations_do(
        sub {
            foreach my $domain_name (
                qw/example.org native.example.org native.example.com/)
            {
                my $domain = $self->domains->create(
                    {
                        name => $domain_name,
                        type => 'NATIVE',
                    }
                );
                foreach my $i ( 1 .. 9 ) {

     # 2001:db8:: is reserved for documentation purposes
     # by higher powers on the internets. Not sure if that
     # includes test fixtures, but that is
     # what I am using in any case.
                    $self->records->create(
                        {
                            name      => "aaaa-record-$i." . $domain->name,
                            domain_id => $domain->id,
                            type      => 'AAAA',
                            content =>
                              "2001:0db8:0000:0000:0000:0000:0000:00$i",
                            ttl => '3600',
                        }
                    );
                    $self->records->create(
                        {
                            name      => "a-record-$i." . $domain->name,
                            domain_id => $domain->id,
                            type      => 'A',
                            content   => "192.168.1.$i",
                            ttl       => '3600',
                        }
                    );
                }

                # Create A record with a cname hanging off it
                $self->records->create(
                    {
                        name      => 'a-record-with-cname.' . $domain->name,
                        domain_id => $domain->id,
                        type      => 'A',
                        content   => '192.168.2.1',
                        ttl       => '3600',
                    }
                );

                $self->records->create(
                    {
                        name      => 'cname.' . $domain->name,
                        domain_id => $domain->id,
                        type      => 'CNAME',
                        content   => 'a-record-with-cname.' . $domain->name,
                        ttl       => '3600',
                    }
                );

                # Create MX record for the domain
                $self->records->create(
                    {
                        name      => 'mx-record.' . $domain->name,
                        content   => 'a-record-1' . $domain->name,
                        domain_id => $domain->id,
                        type      => 'MX',
                        prio      => 0,
                        ttl       => 14400,
                    }
                );
            }

            # Create PTR records
            my $ptr_domain = $self->domains->create(
                {
                    name => '1.168.192.in-addr.arpa',
                    type => 'NATIVE',
                }
            );
            my $ptr_domain_6 = $self->domains->create(
                {
                    name => '0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa',
                    type => 'NATIVE',
                }
            );

            # Some /^A(AAA)?$/ records will not have a corresponding PTR (6..9)
            foreach my $i ( 1 .. 5 ) {
                $self->records->create(
                    {
                        name      => $i . ".1.168.192.in-addr.arpa",
                        domain_id => $ptr_domain->id,
                        type      => 'PTR',
                        content   => "a-record-$i.example.org",
                        ttl       => '3600',
                    }
                );
                $self->records->create(
                    {
                        name =>
"$i.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa",
                        domain_id => $ptr_domain_6->id,
                        type      => 'PTR',
                        content   => "aaaa-record-$i.example.org",
                        ttl       => '3600',
                    }
                );
            }

            $self->domains->create(
                {
                    name => 'master.example.org',
                    type => 'MASTER',
                }
            );
        }
    ); }

1;

__DATA__

--
-- Created by SQL::Translator::Producer::SQLite
--

BEGIN TRANSACTION;

--
-- Table: cryptokeys
--
-- DROP TABLE cryptokeys;

CREATE TABLE cryptokeys (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  flags integer NOT NULL,
  active boolean,
  content text,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX cryptokeys_idx_domain_id ON cryptokeys (domain_id);

--
-- Table: domainmetadata
--
-- DROP TABLE domainmetadata;

CREATE TABLE domainmetadata (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  kind varchar(16),
  content text,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX domainmetadata_idx_domain_id ON domainmetadata (domain_id);

--
-- Table: domains
--
-- DROP TABLE domains;

CREATE TABLE domains (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  master varchar(20) DEFAULT null,
  last_check integer,
  type varchar(6) NOT NULL,
  notified_serial integer,
  account varchar(40) DEFAULT null
);

CREATE UNIQUE INDEX name_index ON domains (name);

--
-- Table: records
--
-- DROP TABLE records;

CREATE TABLE records (
  id INTEGER PRIMARY KEY NOT NULL,
  domain_id integer,
  name varchar(255) DEFAULT null,
  type varchar(10) DEFAULT null,
  content varchar(255) DEFAULT null,
  ttl integer,
  prio integer,
  change_date integer,
  ordername varchar(255),
  auth boolean,
  FOREIGN KEY(domain_id) REFERENCES domains(id)
);

CREATE INDEX records_idx_domain_id ON records (domain_id);

--
-- Table: supermasters
--
-- DROP TABLE supermasters;

CREATE TABLE supermasters (
  ip varchar(25) NOT NULL,
  nameserver varchar(255) NOT NULL,
  account varchar(40) DEFAULT null
);

--
-- Table: tsigkeys
--
-- DROP TABLE tsigkeys;

CREATE TABLE tsigkeys (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255),
  algorithm varchar(255),
  secret varchar(255)
);

CREATE UNIQUE INDEX namealgoindex ON tsigkeys (name, algorithm);

COMMIT;
