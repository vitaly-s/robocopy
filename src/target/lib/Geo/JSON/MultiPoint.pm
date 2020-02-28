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

1;