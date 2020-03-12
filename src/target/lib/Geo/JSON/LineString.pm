package Geo::JSON::LineString;

use strict;
use warnings;
use Carp;

use base qw(Geo::JSON::Geometry);
use TypeDefs;

sub _init {
    my ($self, $args) = @_;
    $self->SUPER::_init($args);

    croak "Required argument 'coordinates'" unless exists $args->{coordinates};

    if (exists $args->{coordinates}) {
        my $value = $args->{coordinates};
        LineString->check($value) || croak "'coordinates' value must be 'LineString'";
        $self->{coordinates} = $value;
    }
}

sub inside
{
    my ($self, $point) = @_;
    return $self->beside($point, 0);
}


sub beside
{
    my ($self, $point, $distance) = @_;
    my $positions = $self->coordinates;
    return undef unless defined $positions;
    return Geo::JSON::Utils::point_around_line($point, $positions, $distance);
#    my $L0 = $positions->[0];
#    foreach my $i ( 1 .. $#{$positions} ) {
#        my $L1 = $positions->[$i];
#        return !!1 if Geo::JSON::Utils::point_around_segment($point, $L0, $L1, $distance);
#        $L0 = $L1;
#    }
#    undef;
}

1;