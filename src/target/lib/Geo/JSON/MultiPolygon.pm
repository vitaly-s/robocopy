package Geo::JSON::MultiPolygon;

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
        Polygons->check($value) || croak "'coordinates' value must be 'Polygons'";
        $self->{coordinates} = $value;
    }

}

sub all_positions {
    my $self = shift;

    return [
        map { @{$_} }
        map { @{$_} } @{ $self->coordinates }
    ];
}


sub inside
{
    my ($self, $point) = @_;
    my $polygons = $self->coordinates;
    return undef unless defined $polygons;
    foreach my $polygon ( @{$polygons}) {
        next unless defined $polygon;
        return !!1 if Geo::JSON::Polygon::_inside($point, $polygon);
    }

    undef;
}

sub beside
{
    my ($self, $point, $distance) = @_;
    my $polygons = $self->coordinates;
    return undef unless defined $polygons;
    my $result;
    foreach my $polygon ( @{$polygons}) {
        next unless defined $polygon;
        unless ($result) {
            foreach my $line( @$polygon ) {
                next unless defined $line;
                $result = !!1 if Geo::JSON::Utils::point_around_line($point, $line, $distance);
                last if $result;
            }
        }
        return undef if Geo::JSON::Polygon::_inside($point, $polygon);
    }
    return $result;
}

sub is_region
{
    !!1;
}

1;