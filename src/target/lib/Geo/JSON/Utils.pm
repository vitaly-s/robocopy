package Geo::JSON::Utils;

use strict;
use warnings;
use Carp;

use base 'Exporter';

our @EXPORT_OK = qw/ compare_positions compute_bbox /;

# TODO improve - need to ensure floating points are the same
sub compare_positions {
    my ( $pos1, $pos2 ) = @_;

    # Assume positions have same number of dimensions
    my $dimensions = defined $pos1->[2] ? 2 : 1;

    foreach my $dim ( 0 .. $dimensions ) {

        # TODO fix stringification problems...?
        return 0
            if ( defined $pos1->[$dim] && !defined $pos2->[$dim] )
            || ( !defined $pos1->[$dim] && defined $pos2->[$dim] )
            || ( $pos1->[$dim] != $pos2->[$dim] );
    }

    return 1;
}

sub compute_bbox {
    my $positions = shift;    # arrayref of positions

    croak "Need an array of at least 2 positions"
        unless ref $positions
        && ref $positions eq 'ARRAY'
        && @{$positions} > 1;

    # Assumes all have same number of dimensions

    my $dimensions = scalar @{ $positions->[0] } - 1;

    my @min = my @max = @{ $positions->[0] };

    foreach my $position ( @{$positions} ) {
        foreach my $d ( 0 .. $dimensions ) {
            $min[$d] = $position->[$d] if $position->[$d] < $min[$d];
            $max[$d] = $position->[$d] if $position->[$d] > $max[$d];
        }
    }

    return [ @min, @max ];
}

1;
