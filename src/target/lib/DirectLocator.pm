package DirectLocator;

use Carp;
use base qw(Locator);
use Geo::Address;
use Geo::Place;
use Geo::Coder;
use Geo::JSON::Utils;


#use Geo::JSON::Types;
#use TypeDefs;

sub _from_cache
{
    undef;
}

sub _to_cache
{
    my ($self, $latitude, $longitude, $address) = @_;

    $address;
}

1;
