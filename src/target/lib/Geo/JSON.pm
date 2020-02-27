package Geo::JSON;

use strict;
use warnings;
use Carp;

#use JSON qw/ decode_json /;
#use JSON::XS;
use JSON::XS qw/ /;
#use List::Util qw/ first /;

#use Geo::JSON::Geometry;
#use Geo::JSON::Point;
#our $json_codec = JSON::XS->new->canonical(1)->pretty->utf8->convert_blessed(1);
our $json_codec = JSON::XS->new->utf8->convert_blessed(1);

#use constant GEOMETRY_OBJECTS => [
#    qw/ Point MultiPoint LineString MultiLineString Polygon MultiPolygon GeometryCollection /
#];

sub from_json {
    my $json = shift;

    my $data = JSON::XS->new->utf8->decode($json);


    return load($data);
}

sub load {
    my $data = shift;

    croak "load requires a JSON object (hashref)"
        unless ref $data eq 'HASH';

    my $type = delete $data->{type}
        or croak "Invalid JSON data: no type specified";

    my $geo_json_class = 'Geo::JSON::' . $type;

#    print "!!! JSON::load load module '$geo_json_class'\n";
    eval "require $geo_json_class";
    croak "Unable to load '$geo_json_class'; $@" if $@;

#    print "!!! create instance '$geo_json_class'\n";
    return $geo_json_class->new($data);
}


1;

