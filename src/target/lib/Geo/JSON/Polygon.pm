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

1;