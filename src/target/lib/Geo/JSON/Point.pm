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

1;