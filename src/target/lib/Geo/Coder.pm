package Geo::Coder;

use strict;
use warnings;
use Carp;

use base 'Exporter';

#our @EXPORT = qw( reverse_geocode );

require Geo::Address;

sub QUALITY_HIGH { 'building' }
sub QUALITY_LOW { 'city' }
sub DEFAULT_LANGUAGE { 'en' }

1;

