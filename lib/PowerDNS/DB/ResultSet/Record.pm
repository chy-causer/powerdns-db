package PowerDNS::DB::ResultSet::Record;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

use Data::Dumper;
use Carp;
use 5.014;
use Net::IP;
use Try::Tiny;

=head1 NAME

PowerDNS::DB::ResultSet::Record - ResultSet methods for Record objects

=head1 SYNOPSIS

The Record ResultSet class associated with the L<PowerDNS::DB> schema.

=head1 DESCRIPTION

This class is responsible for overriding ResultSet operations on PowerDNS
record rows. It is derived from L<DBIx::Class::ResultSource> objects.

Methods here override some key methods used by DBIx. For the most part,
they are for validation, but there are some instances where datasets are
changed and implicit updates are done. See the method descriptions themselves
for further details

=head1 METHODS

=head2 update

    $resultset->update({ttl => 900});

=over

=item Arguments: hashref

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass> or undef

=back

This method is not advised as yet because it retrieves each record in turn, validates
them individually, and if any of them fail, it rollbacks the transaction.

Will be optimized eventually.

=cut

sub update {
    my ( $self, $col_data, $extra_parameters ) = @_;
    #TODO: Optimize
    eval {
        $self->result_source->schema->txn_do(sub {
                foreach my $row ( $self->all ) {
                    $row->update($col_data, $extra_parameters) or die "Rollback";
                }
            });
    };
    die $@ if $@;
    return $self;
}

=head2 create

   my $row = $pdns->records->create($col_data, $extra_parameters);

=over

=item Arguments: \%col_data, \%extra_parameters

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

The same any normal ResultSet create, except \%extra_parameters is passed
over to the L</new_result> method.

=cut

sub create {
    my ( $self, $col_data, $extra_parameters ) = @_;
    $extra_parameters ||= {};
    return $self->new_result($col_data, $extra_parameters)->insert;
}

=head2 new_result

=over

=item Arguments, \%col_data, \%extra_parameters

=item Return Value: L<$result|DBIx::Class::Manual::ResultClass>

=back

The same as a normal ResultSet new_result, except that it has \%extra_parameters
which is passed to the new $row, and you can supply a "domain_name" key in the \%col_data,
which is changed into a domain object.

=cut

sub new_result {
    my ( $self, $col_data, $extra_parameters ) = @_;
    $extra_parameters ||= {};

    # Put any supplied domain name to one side
    my $domain_name = $col_data->{domain_name};
    delete $col_data->{domain_name};

    # Create the row
    my $row = $self->next::method($col_data);

    # And try to add the domain from the domain_name
    # afterwards
    if ( $domain_name ) {
        my $domain = $self->result_source->schema->domains->find({
                name => $domain_name
        },
        { columns => [qw/id/]});
        $row->set_column( 'domain_id', $domain->id ) if $domain;
    }
    if ( $extra_parameters->{create_ptr} ) {
        $row->create_reverse_record;
    }
    return $row;
}

=head2 record_pair

    use Data::Dumper;
    my $pair = $pdns->records->record_pair('192.168.56.1');
    if ( $pair ) {
        print Dumper($pair->{forward}, $pair->{reverse});
    }
    else {
        print "No paired record found for this IP address
    }


=over

=item Arguments: $ip_address

=item Return Value: $hashref with keys "forward" and "reverse", or undef if no pair found

=back

DNS traditionally separates forward records from reverse PTR records. This is often an unused feature and
most times, people want to treat the mapping of IP and DNS name as a pair. This method will, given an IP
address, search the database for an A or AAAA record at that address, and return only if it has a PTR record
associated with it.

In nearly all situtions, a PTR record for an IP address should be unique. In
other words, looking up the PTR of 192.168.1.1 should only turn up 
one result. If for whatever reason it is a round robin (it really shouldn't be),
then this method dies. 

=cut
sub record_pair {
    my ( $self, $ip_address ) = @_;
    my $ip = Net::IP->new($ip_address);
    croak "Invalid IP supplied: $ip_address" if not $ip;

    # Net::IP::reverse_ip adds a trailing dot. PowerDNS does not
    # use a trailing dot. Fix.
    #
    # TODO: Duplication in PowerDNS::DB::Row::Record. Remove.
    my $reverse_ip = $ip->reverse_ip =~ s/\.$//r;

    # Assume that there is only one PTR record in the
    # database
    my $reverse = $self->search( {
            type => 'PTR',
            name => $reverse_ip,
        });

    die "paired records only works for unique PTR records" if $reverse->count > 1;

    my $record_type;
    given ( $ip->version ) {
        when (4) {
            $record_type = 'A';
        }
        when (6) {
            $record_type = 'AAAA';
        }
        default {
            die "Shouldn't get here";
        }
    }

    my $forward;
    if ( $reverse->count ) {
        $forward= $self->search_ip(
                 $ip->ip,
            )->search({
                name => $reverse->first->content,
            });
    }
    else {
        return;
    }

    # $forward->[0] is OK because we should only ever be
    # receiving one of these records
    return {
        forward => $forward->first,
        reverse => $reverse->first,
    };
}

=head2 search_ip

    $records->search_ip('192.168.010.092');

=over

=item Arguments: $ip_address

=item Return Value: $result_set or @rows

=back

PostgreSQL specific code makes the matching of IP addresses much better than
in other databases because it has the inet type.

If you don't use PostgreSQL, the function will still work, but the matching will
not be as good

192.168.2.1 and 192.168.002.001 are syntactically different by symantically the same.
This function will make it so these two addresses match. Will ONLY work in PostgreSQL. You
have been warned.

=cut

sub search_ip {
    my ( $self, $ip_address, $backend_type ) = @_;

    $backend_type ||= $self->result_source->storage->sqlt_type;

    my $ip = Net::IP->new($ip_address)
        or croak "Invalid IP address supplied";

    given ($backend_type) {
        when ('PostgreSQL') {
            try {
                return $self->search({},
                    {
                        'select' => [qw/
                            name
                            domain_id
                            content::inet
                            type
                            ttl
                        /],
                        'as' => [qw/
                            name
                            domain_id
                            content
                            type
                            ttl
                        /],
                        'where' => {
                            'content::inet' => $ip->ip,
                            type => [qw/A AAAA/],
                        }
                    });
            }
            catch {
                warn "There is an invalid item in the PostgreSQL database. Falling back to dumb behaviour";
                # SMELL: return is for the catch, not the search_ip function 
                return $self->search_ip($ip_address, 'not PostgreSQL');
            };
        }
        default {
            return $self->search({
                type => [qw/A AAAA/],
                content => $ip_address
            });
        }
    }
}

=head2 next_serial

    my $integer = $records->next_serial;

=over

=item Arguments: None

=item Return Value: integer

Returns the next serial to be used. In format YYMMDDnn. Searches the database to find the next value.

If today is 20130720, then this is how it would return

=over

=item Finds 2013072003, returns 2013072004

=item Finds nothing, returns 2013072000

=item Finds 2013071903, returns 2013072000

=item Finds 2013072099, returns 2013072100, issues no warning.

=item Finds 2999072099, returns 2999072100, issues a warning.

=back

=cut

sub next_serial {
    my ( $self ) = @_;

    my $today = strftime('%Y%m%d', @{[localtime]});
    
    my $current_serial = $self->current_serial;

    if ( not $current_serial ) {
        warn "Cannot find a record serial";
        return $today . '00';
    }
    else {
        if ( $current_serial > substr($today, 0, -2 ) ) {
            warn "Unusual serial value. Just incrementing by one";
            return $current_serial + 1;
        }
        elsif ( $current_serial =~ /^$today\d\d/ ) {
            # SMELL: Can overflow if > 100 changes in a day
            return $current_serial + 1;
        }
        else {
            return $today . '00';
        }
    }
}

=head2 current_serial

=over

=item Arguments: None

=item Return Value: Integer or null

=back

Returns the highest changedate in the database, or null if nothing exists

=cut

sub current_serial {
    my ( $self ) = @_;
    return $self->search({}, {
                order_by => { -desc =>  'changedate' },
                columns => 'changedate',
            })->first;
}


1;

__END__

=head1 AUTHOR

Christopher Causer C<<christopher.causer@it.ox.ac.uk>>

=head1 BUGS

Please report any bugs or feature requests to the L</AUTHOR>

=head1 ACKNOWLEDGEMENTS

I would like to thank Augie Schwer and his PowerDNS::Backend::MySQL which 
I used as a springboard to create this module.

=head1 COPYRIGHT & LICENSE

Copyright 2013 Oxford University IT Services

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
