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

1;