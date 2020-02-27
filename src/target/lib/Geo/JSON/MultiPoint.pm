package Geo::JSON::MultiPoint;

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
        Positions->check($value) || croak "'coordinates' value must be 'Positions'";
        $self->{coordinates} = $value;
    }
}


1;