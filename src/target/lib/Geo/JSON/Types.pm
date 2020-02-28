package Geo::JSON::Types;

use strict;
use warnings;
use Carp;
use Scalar::Util;
use Geo::JSON::Utils qw/ compare_positions /;

BEGIN {

    use TypeDefs
    qw/ 
        Rectangle 
        LinearRing
        LineString
        LineStrings
        Polygon
        Polygons
        Position
        Positions
        Geometry
        Geometries
    /;

    declare Rectangle,
        as ArrayRef [Num],
        where { @{$_} == 4 };

    declare Position,
        as ArrayRef [Num],
        where { @{$_} >= 2 };
        
    declare Positions,
        as ArrayRef[Position],
        where { @{$_} > 0 };

    declare LineString,
        as Positions,
        where { @{$_} >= 2 };

    declare LineStrings,
        as ArrayRef [LineString];

    declare LinearRing,
        as LineString,
        where { @{$_} >= 4 && compare_positions( $_->[0], $_->[-1] ) };

    declare Polygon,
        as ArrayRef [LinearRing];

    declare Polygons,
        as ArrayRef [Polygon];
        
    declare Geometry, 
        as Object, 
        where { $_->isa("Geo::JSON::Geometry") };

    coerce Geometry,
        from HashRef, via { Geo::JSON::load($_) };

    declare Geometries,
        as ArrayRef [Geometry];
}

1;
