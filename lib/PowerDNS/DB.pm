use utf8;
package PowerDNS::DB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-05-31 10:30:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Yne/Acbbhev3F/HigWSNng

use 5.014;
use Carp;
use Try::Tiny;
use Data::Dumper;
use PowerDNS::Validator::Result;
use PowerDNS::Validator::Records;
use PowerDNS::Validator::Domains;


=head1 NAME

PowerDNS::DB - Provides an interface to manipulate PowerDNS data in the database backend. It is
a subclass of L<DBIx::Class> so anything possible in that module is possible here. Exceptions
to this rule occur when validations are used, which limit what can be entered into the database.

There are some methods that have been disabled because their functionality has not yet been
implemented. These methods will throw an error.

=cut
our $VERSION = '0.01';

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use PowerDNS::DB;

    #Create the PowerDNS::DB object
    my $pdns = PowerDNS::DB->new( @dbix_connection_args );

=head1 DESCRIPTION

PowerDNS::DB provides a layer of abstraction
for manipulating the data stored in the PowerDNS DB backend.

=cut

sub _debug {
    my ( $self, $level, @messages ) = @_;
    if ( $level < $self->{debug_level} ) {
        print STDERR @messages, "\n";
    }
}

=head1 METHODS

=head2 connect(\%params)

    my $params = {
            db_user         =>  'pdns',
            db_pass         =>  'wibble',
            dsn         =>  'dbi:Pg:dbname=pdns',
    };

    my $pdns = PowerDNS::DB->connect($params);


Please see L<DBIx::Class/connect> for arguments and connection options.

=cut

#sub connect{
# Nothing to see here
#}

=head2 records

=over

=item Arguments: None

=item Return value: L<Record ResultSet|PowerDNS::DB::ResultSet::Record>.

=back

=cut 

sub records { (shift)->resultset('Record') };

=head2 domains

=over

=item Arguments: None

=item Return value: L<Domain ResultSet|PowerDNS::DB::ResultSet::Domain>.

=back

=cut

sub domains { (shift)->resultset('Domain') };

=head2 last_validation() :lvalue

If you have run an action which required a validation (pretty much everything), the
last validation result is retrieveable from this method.

(Although this method is an :lvalue, please do not use that. It is being
used internally.

=cut

sub last_validation :lvalue { (shift)->{'_pdns_last_validation'}};


=head2 validators([@validators])

Returns the list of current validators that are being used.

If an  array of @validators is supplied, the validator list
is modified (not appended) to be that list.

=cut

sub validators {
    my ( $self, @validators ) = @_;

    # Allow people to hose the validators list should they so wish.
    if ( @validators ) {
        $self->{_pdns_validators} = \@validators;
    }

    $self->{_pdns_validators} ||
        $self->add_validator(
            PowerDNS::Validator::Domains->new,
            PowerDNS::Validator::Records->new,
        );
    return @{$self->{_pdns_validators}};
}

=head2 add_validator($validator_object)

    $db->add_validator(MyOrganization::PowerDNS::Validator->new({
        db => $db,
        username => $username
    });

Before actions are performed, the action is run past all the validators before being
done. This ensures that data going into the database is safe, and RFC compliant (to
the best of my ability to write a validator.)

There are two validators included by default, L<PowerDNS::Validator::Domains>, and
L<PowerDNS::Validator::Records>. These validators will make sure that everything is
above board before creation or modification of domain and record records respectively.
Neither does authorization checking.

To create your own validator, please see L<PowerDNS::Validator::Deny> for a very
basic implementation of a validator. This will deny everything, but the documentation
there will hopefully explain enough to get you started.

=cut

sub add_validator {
    my ( $self, @validators ) = @_;
    foreach my $validator (@validators) {
        $validator->schema = $self;
    }
    push @{$self->{_pdns_validators}}, @validators;
}

=head2 no_validations_do(\&coderef, @coderef_args)

    $db->no_validations_do(
        sub{
            my $name = shift; # wibble
            $db->records->create({
                name => $name,
                type= => 'INVALID TYPE',
                content => 'INVALID CONTENT',
            });
        }, 'wibble'
    );

Sometimes, the validations can be too stringent. If you wish
to modify the database and not be bound by the shackles of validations, then 
wrapping the code with this method will stop any validations from  happening.

If there are safeguards on the database itself, then this method will not help
you and you will be told as much.

=cut

sub no_validations_do {
    my ( $self, $coderef, @coderef_args ) = @_;
    my @stashed_pdns_validators = $self->validators;
    $self->{_pdns_validators} = [];

    my @rtn;

    try {
        if ( wantarray ) {
            @rtn =  $coderef->(@coderef_args);
        }
        elsif (defined wantarray ) {
            $rtn[0] = $coderef->(@coderef_args);
        }
        else {
            $coderef->(@coderef_args);
        }
    }
    catch {
        die $_;
    }
    finally {
        $self->{_pdns_validators} = \@stashed_pdns_validators;
    };
    
    return wantarray ? @rtn : $rtn[0];
}

=head2 validate($action, \%dns_record)

Makes sure that the $action is an action that is permitted by the $db instance. It will
return a L<PowerDNS::Validator::Result> object

=cut

sub validate {
    my ( $self, $action, $row, @extra_parameters ) = @_;
    croak "Unknown action"
        unless $action ~~ [
            'update record',
            'create record',
            'delete record',
            'update domain',
            'create domain',
            'delete domain',
        ];
    $action = 'validate_' . ( $action =~ tr/ /_/r );

    my $result = PowerDNS::Validator::Result->new( {package => __PACKAGE__} );
   
    my $caller = [ caller 1 ];

    $result->debug = {
            action => $action,
            row    => $row,
            extra_parameters => \@extra_parameters,
            caller => $caller,
    };
    
    my $shortcircuit = 0;
    foreach my $validator ( $self->validators ) {
        die "$validator is not a validator"
            if not ref $validator or not $validator->isa('PowerDNS::Validator::Base');
        return $result if $shortcircuit;
        if ( $validator and $validator->can($action) ) {
            try {
                my $new_result = $validator->$action($row, @extra_parameters);
                die (
                    sprintf "FATAL: Validator %s is returning a non result object: %s",
                        ref $validator,
                        $new_result
                ) if not $new_result or not $new_result->isa('PowerDNS::Validator::Result');
                $result += $new_result;
            } catch {
                croak $_ unless ref $_; # Don't care about simple 'die's
                when ( $_->isa('PowerDNS::Validator::Result' ) ) {
                    # Is a shortcircuiting error. Just return without
                    # running any more validators;
                    #
                    # Because Try::Tiny doesn't work well with foreach
                    # loops, you have to jump through the $shortcircuit = 1
                    # hoop to get it to do what you want.
                    $result += $_;
                    $shortcircuit = 1;
                }
                default {
                    die $_;
                }
                0;
            };
            
        }
        else {
            warn "$validator is missing method $action";
        }
    }
    $self->last_validation = $result;
    return $result;
}

1;
__END__

=head1 VALIDATIONS

This module tries pretty hard to make sure that data is valid before being put
into the database. This includes content that is different syntactically but the same
semantically (e.g. 10.0.0.1 and 010.000.000.001).

However, it may be that you wish to constrain it further. In that case you will want to
write your own validations module.

TODO: Document how to write your own validations


=head1 AUTHOR

Christopher Causer C<<christopher.causer@it.ox.ac.uk>>

=head1 BUGS

Please report any bugs or feature requests to the L</AUTHOR>

=head1 ACKNOWLEDGEMENTS

I would like to thank Augie Schwer and his L<PowerDNS::Backend::MySQL> which 
I used as a springboard to create this module.

=head1 COPYRIGHT & LICENSE

Copyright 2012 Oxford University IT Services

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
