use utf8;

package PowerDNS::Validator::UniquePTR;
use parent qw(PowerDNS::Validator::Base);

use 5.014;
use Carp;

sub validate_create_record {
    my ( $self, $row, $extra_parameters ) = @_;

    $row = $self->_sanitize_row($row);
    return $self->validate_ptr_is_unique($row);
}

sub validate_update_record {
    my ( $self, $dirty_row, $updated_values, $extra_parameters ) = @_;
    my $result = $self->_new_result;

    
    my $row;
    ( $row, $updated_fields ) = $self->_separate_clean_from_dirty($dirty_row, $updated_fields);


    return $result if not 'name' ~~ [ keys $updated_fields ];
    

    return $self->validate_ptr_is_unique($row, $updated_fields->{name});
}

sub validate_ptr_is_unique {
    my ( $self, $row, $name_field ) = @_;

    my $result = $self->_new_result;
    
    $name_field ||= $row->name;


    return $result
        if not $row->type eq 'PTR';

    # Assume content is good because the PowerDNS::Validator::Records has already done
    # its thing
    
    $result += $self->validate_field_is_unique($row, 'name', $name_field);

    # TODO: Could do with a friendlier message than the stock message from validate_field_is_unique
    return $result;
}


