package Geo::JSON::Utils;

use strict;
use warnings;
use Carp;

use base 'Exporter';

our @EXPORT_OK = qw/ compare_positions compute_bbox 
        point_in_poly point_around_segment point_around_point point_in_bbox /;

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

sub is_2d_point ($)
{
    ref($_[0]) eq 'ARRAY' && scalar(@{$_[0]}) >= 2;
}

sub point_in_bbox {
    my ($point, $bbox) = @_;
    
    croak "'point' not 2D point" unless is_2d_point($point);
    croak "'bbox' not box"
        unless ref $bbox
            && ref $bbox eq 'ARRAY'
            && @$bbox == 4;
            
    return !!1 if ($point->[0] >= $bbox->[0]) && ($point->[0] <= $bbox->[2]) 
                && ($point->[1] >= $bbox->[1]) && ($point->[1] <= $bbox->[3]);
    undef;
}

#
# See: https://www.inf.usi.ch/hormann/papers/Hormann.2001.TPI.pdf
#
sub INNER_CODE { 1 }
sub EDGE_CODE { 2 }
sub VERTEX_CODE { 3 }
sub point_in_poly ($$)
{
    my ($R, $P) = @_;

    croak "R not 2D point" unless is_2d_point($R);
    croak "P not linear ring"
        unless ref $P
        && ref $P eq 'ARRAY'
        && @{$P} > 2
        && compare_positions( $P->[0], $P->[-1] );

    # if ((P[0].Y == R.Y) && (P[0].X == R.X))
    return VERTEX_CODE if (($P->[0]->[0] == $R->[0]) && ($P->[0]->[1] == $R->[1]));

    my $wn = 0;
    my $n = scalar(@$P) - 2;
    my $R_x = $R->[0];
    my $R_y = $R->[1];
    foreach my $i ( 0 .. $n ) {
        my $P_0 = $P->[$i];
        my $P_1 = $P->[$i + 1];
        # if (P[i + 1].Y == R.Y)
        if ($P_1->[1] == $R->[1]) {
            # if (P[i + 1].X == R.X)
            return VERTEX_CODE if ($P_1->[0] == $R->[0]);
            # if ((P[i].Y == R.Y) && ((P[i + 1].X > R.X) == (P[i].X < R.X)))
            return EDGE_CODE if (($P_0->[1] == $R->[1]) && (($P_1->[0] > $R->[0]) == ($P_0->[0] < $R->[0])));
        }
        # if (crossing(P[i], P[i+1], R)) : ((Pi.Y < R.Y) != (Pi1.Y < R.Y));
        if (($P_0->[1] < $R->[1]) != ($P_1->[1] < $R->[1])) {
            # d = (P[i].X - R.X) * (P[i + 1].Y - R.Y) - (P[i + 1].X - R.X) * (P[i].Y - R.Y);
            my $det = ($P_0->[0] - $R->[0]) * ($P_1->[1] - $R->[1]) 
                - ($P_1->[0] - $R->[0]) * ($P_0->[1] - $R->[1]);
            return EDGE_CODE if $det == 0.0;
            # if (P[i + 1].Y > P[i].Y)
            if ($P_1->[1] > $P_0->[1]) {
                $wn += 1 if $det > 0;
            }
            else {
                $wn -= 1 unless $det > 0;
            }
        }
    }
    return INNER_CODE if $wn != 0;
    undef;
}

# See: http://www.cyberforum.ru/free-pascal/thread1654005.html
sub point_around_segment($$$$)
{
    my ($R, $L1, $L2, $dist) = @_;

    croak "R not 2D point" unless is_2d_point($R);
    croak "L1 not 2D point" unless is_2d_point($L1);
    croak "L2 not 2D point" unless is_2d_point($L2);
    croak "Invalide distance value" unless defined($dist) && $dist >= 0;
    
    # a = (R.X - L1.X) ^ 2 + (R.Y - L1.Y) ^ 2
    my $a = ($R->[0] - $L1->[0]) * ($R->[0] - $L1->[0]) 
        + ($R->[1] - $L1->[1]) * ($R->[1] - $L1->[1]);
    # b = (R.X - L2.X) ^ 2 + (R.Y - L2.Y) ^2
    my $b = ($R->[0] - $L2->[0]) * ($R->[0] - $L2->[0]) 
        + ($R->[1] - $L2->[1]) * ($R->[1] - $L2->[1]);
#    double c = (L2.X - L1.X) ^ 2 + (L2.Y - L1.Y) ^ 2
    my $c = ($L2->[0] - $L1->[0]) * ($L2->[0] - $L1->[0]) 
        + ($L2->[1] - $L1->[1]) * ($L2->[1] - $L1->[1]);

    # if ((a + c) <= b)
    if (($a + $c) <= $b) {
        return ($a <= $dist * $dist);
    }
    # if ((b + c) < a)
    if (($b + $c) <= $a) {
        return ($b <= $dist * $dist);
    }
    # s2 = ABS((R.X - L2.X) * (L1.Y - L2.Y) - (L1.X - L2.X) * (R.Y - L2.Y))
    my $s2 = abs(($R->[0] - $L2->[0]) * ($L1->[1] - $L2->[1]) 
        - ($L1->[0] - $L2->[0]) * ($R->[1] - $L2->[1]));
    # return (s2 / SQRT(c)) <= dist);
    return (($s2 / sqrt($c)) <= $dist);
}

sub point_around_line($$$)
{
    my ($point, $line, $dist) = @_;

    croak "'point' not 2D point" unless is_2d_point($point);
    croak "Invalide distance value" unless defined($dist) && $dist >= 0;
    croak "'line' not linear"
        unless ref $line
        && ref $line eq 'ARRAY'
        && @{$line} > 1;
        
    my $L0 = $line->[0];
    foreach my $i ( 1 .. $#{$line} ) {
        my $L1 = $line->[$i];
        return !!1 if point_around_segment($point, $L0, $L1, $dist);
        $L0 = $L1;
    }
    undef;
}

sub point_around_point($$$)
{
    my ($R, $P, $dist) = @_;

    croak "R not 2D point" unless is_2d_point($R);
    croak "P not 2D point" unless is_2d_point($P);
    croak "Invalide distance value" unless defined($dist) && $dist > 0;

    my $a = ($R->[0] - $P->[0]) * ($R->[0] - $P->[0]) 
        + ($R->[1] - $P->[1]) * ($R->[1] - $P->[1]);
    return ($a < ($dist * $dist));
}
1;
