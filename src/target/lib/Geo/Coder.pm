package Geo::Coder;

use strict;
use warnings;
use Carp;

use base 'Exporter';

our @EXPORT = qw( create_geocoder );

require Geo::Address;

sub DEFAULT_LANGUAGE { 'en' }


sub create_geocoder
{
    my $args = scalar @_ == 1 
        ? (ref $_[0] eq 'HASH' 
            ? {%{$_[0];}}
            : croak('Single parameters to new() must be a HASH ref data => ' . $_[0] . "\n")
        )
        : (@_ % 2 
            ? croak("The method expects a hash reference or a" 
                . " key/value list. You passed an odd number of arguments\n") 
            : {@_}
        );
    my $type = delete $args->{coder} || 'OSM';
    my $coder_class = 'Geo::Coder::' . $type;

    eval "require $coder_class";
    croak "Coder '$type' not supported. $@" if $@;

    return $coder_class->new($args);
}
1;

