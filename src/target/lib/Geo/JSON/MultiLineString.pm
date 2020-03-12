package Geo::JSON::MultiLineString;

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
        LineStrings->check($value) || croak "'coordinates' value must be 'LineStrings'";
        $self->{coordinates} = $value;
    }

}

sub all_positions {
    my $self = shift;

    return [ map { @{$_} } @{ $self->coordinates } ];
}

sub inside
{
    my ($self, $point) = @_;
    return $self->beside($point, 0);
}

sub beside
{
    my ($self, $point, $distance) = @_;
    my $lines = $self->coordinates;
    return undef unless defined $lines;
    foreach my $line( @$lines ) {
        next unless defined $line;
        return !!1 if Geo::JSON::Utils::point_around_line($point, $line, $distance);

#        my $L0 = $line->[0];
#        foreach my $i ( 1 .. $#{$line} ) {
#            my $L1 = $line->[$i];
#            return !!1 if Geo::JSON::Utils::point_around_segment($point, $L0, $L1, $distance);
#            $L0 = $L1;
#        }
    }
    undef;
}


1;