package Geo::JSON::Point;

#use strict;
#use warnings;
use Carp qw/ croak /;
use Scalar::Util;

use base qw(Geo::JSON::Geometry);
use TypeDefs;

sub _init {
    my ($self, $args) = @_;

    $self->SUPER::_init($args);

    croak "Required argument 'coordinates'" unless exists $args->{coordinates};

    if (exists $args->{coordinates}) {
        my $value = $args->{coordinates};
        Position->check($value) || croak "'coordinates' value must be 'Position'";
        $self->{coordinates} = $value;
    }
    
}



sub all_positions { 
    [ shift->coordinates ] 
}

sub compute_bbox {
    undef; #croak "Can't compute_bbox with a single position";
}

sub inside
{
    my ($self, $point) = @_;
    my $position = $self->coordinates;
    return undef unless defined $position;
    Geo::JSON::Utils::compare_positions($point, $position);
}

sub beside
{
    my ($self, $point, $distance) = @_;
    my $position = $self->coordinates;
    return undef unless defined $position;
    Geo::JSON::Utils::point_around_point($point, $position, $distance);
}

1;