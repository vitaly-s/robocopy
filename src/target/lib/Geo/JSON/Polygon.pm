package Geo::JSON::Polygon;

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
        Polygon->check($value) || croak "'coordinates' value must be 'Polygon'";
        $self->{coordinates} = $value;
    }

}

sub all_positions {
    my $self = shift;

    return [ map { @{$_} } @{ $self->coordinates } ];
}

sub _inside
{
    my ($point, $regions) = @_;
    return undef unless defined $regions && ref $regions eq 'ARRAY' && @{$regions} > 0;
    return undef unless Geo::JSON::Utils::point_in_poly($point, $regions->[0]);
    # validating point in holes
    foreach my $i (1.. $#{$regions}) {
        return undef if Geo::JSON::Utils::point_in_poly($point, $regions->[$i]) == Geo::JSON::Utils::INNER_CODE;
    }
    return !!1;
}

sub inside
{
    my ($self, $point) = @_;
    return !!1 if _inside($point, $self->coordinates);
    undef;
#    my $regions = $self->coordinates;
#    return undef unless defined $regions;
#    return undef unless Geo::JSON::Utils::point_in_poly($point, $regions->[0]);
#    # validating point in holes
#    foreach my $i (1.. $#{$regions}) {
#        return undef if Geo::JSON::Utils::point_in_poly($point, $regions->[$i]) == Geo::JSON::Utils::INNER_CODE;
#    }
#    return !!1;
}


sub beside
{
    my ($self, $point, $distance) = @_;
    my $lines = $self->coordinates;
    return undef unless defined $lines;
    my $result = 0;
    foreach my $line( @$lines ) {
        next unless defined $line;
        $result = 1 if Geo::JSON::Utils::point_around_line($point, $line, $distance);
        last if $result;
    }
    if ($result) {
        return !!1 unless $self->inside($point);
    }
    undef;
}


1;