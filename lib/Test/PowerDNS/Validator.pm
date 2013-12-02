package Test::PowerDNS::Validator;

use strict;
use warnings;

use parent 'Exporter';

our @EXPORT = qw(
  ok_validator_has_warning
  ok_validator_no_warnings
  ok_validator_has_error
  ok_validator_no_errors
);

our @EXPORT_OK = qw(
  ok_validator_has_errors
);

use Test::Builder;

my $Test = Test::Builder->new();

sub ok_validator_has_warning($$;$) {
    my ( $validator_return, $warning_message, $desc ) = @_;
    return (
        $Test->ok( _has_warning( $validator_return, $warning_message ), $desc )
          || $Test->diag(
            "  Wanted '$warning_message'\n" . $validator_return
          )
    );
}

sub ok_validator_no_warnings($;$) {
    my ( $validator_return, $desc ) = @_;
    return ( $Test->ok( !$validator_return->warnings, $desc )
          || $Test->diag( $validator_return ) );
}

sub ok_validator_has_error($$;$) {
    my ( $validator_return, $error_message, $desc ) = @_;
    return (
        $Test->ok( _has_error( $validator_return, $error_message ), $desc )
          || $Test->diag(
            "  Wanted '$error_message'\n" . $validator_return
          )
    );
}

sub ok_validator_has_errors($;$) {
    my ( $validator_result, $desc ) = @_;
    return (
        $Test->ok( $validator_result->errors, $desc )
    );
}

sub ok_validator_no_errors($;$) {
    my ( $validator_return, $desc ) = @_;
    return ( $Test->ok( !$validator_return->errors, $desc )
          || $Test->diag( $validator_return ) );
}

sub _has_error($$) {
    my ( $validator_return, $error_message ) = @_;
    my @res = grep { $_ =~ m/$error_message/ } $validator_return->errors;
    return scalar @res;
}

sub _has_warning($$) {
    my ( $validator_return, $error_message ) = @_;
    my @res = grep { $_ =~ m/$error_message/ } $validator_return->warnings;
    return scalar @res;
}

1;

__END__

=head1 NAME

 Test::PowerDNS::Validator;

=head1 SYNOPSIS

  use Test::More;
  use Test::PowerDNS;

  $db = PowerDNS::DB::Test->new;

  ok_validator_no_errors(
    $db->validate('create record',
        {
          name => 'wibble.example.org',
          domain_id => 1,
          type => 'A',
          content => '192.168.1.222',
        }),
    "Should be able to create a normal A record"
  );

=head1 METHODS

In all functions, $desc is the test description as you would expect in a testsuite.

If a test fails, the validation result is printed to STDERR as a diagnostic tool.

=head2 ok_validator_no_errors($validation_result, $desc)

Fails if the $validation_result has an error

=head2 ok_validator_no_warnings($validation_result, $desc)

Fails if the $validation_result has a warning. Does not fail if it has
an error.

=head2 ok_validator_has_error($validation_result, qr/ERROR_TO_BE_MATCHED/, $desc)

Makes sure that the $validation_result has an error which is matched by the regexp

=head2 ok_validator_has_errors($validation_result, $desc)

Normally won't call this one as you want to search for the error using L</ok_validator_has_error>.
However, when you just want to check that a process failed because of a validation error, this
is a handy function to use.

=head2 ok_validator_has_warning($validation_result, qr/ERROR_TO_BE_MATCHED/, $desc)

Makes sure that the $validation_result has a warning which is matched by the regexp

=cut

