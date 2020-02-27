package Geo::JSON::MultiPolygon;

use strict;
use warnings;
use Carp;

use base qw(Geo::JSON::Geometry);
use TypeDefs;

sub _init {
    my ($self, $args) = @_;
    $self->SUPER::_init($args);

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

1;