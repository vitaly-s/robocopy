package Geo::JSON::MultiPoint;

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
        Positions->check($value) || croak "'coordinates' value must be 'Positions'";
        $self->{coordinates} = $value;
    }
}

#sub all_positions
#{
#    shift->{coordinates};
#}
sub inside
{
    my ($self, $point) = @_;
    my $positions = $self->coordinates;
    return undef unless defined $positions;
    foreach my $position ( @$positions ) {
        return !!1 if Geo::JSON::Utils::compare_positions($point, $position);
    }
    undef;
}

sub beside
{
    my ($self, $point, $distance) = @_;
    my $positions = $self->coordinates;
    return undef unless defined $positions;
    foreach my $position ( @$positions ) {
        return !!1 if Geo::JSON::Utils::point_around_point($point, $position, $distance);
    }
    undef;
}

1;