package Geo::JSON::MultiLineString;

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
        LineStrings->check($value) || croak "'coordinates' value must be 'LineStrings'";
        $self->{coordinates} = $value;
    }

}

sub all_positions {
    my $self = shift;

    return [ map { @{$_} } @{ $self->coordinates } ];
}

1;