package CityLocator;

use Carp;
use base qw(Locator);
use Geo::Address;
use Geo::Place;
use Geo::Coder;
use Geo::JSON::Utils;


#use Geo::JSON::Types;
#use TypeDefs;

sub _init 
{
    my ($self, $args) = @_;
    $self->SUPER::_init($args);
    $self->{city_cache} = [];
    $self->{point_cache} = [];
}

sub _from_cache
{
    my ($self, $latitude, $longitude) = @_;
    foreach my $item (@{$self->{city_cache}}) {
        next unless $item->in_bbox($longitude, $latitude);
        my $geometry = $item->geometry;
        if (defined($geometry) && $geometry->is_region) {
            next unless $geometry->inside([$longitude, $latitude]);
            print STDERR __PACKAGE__, " HIGH accuracy (CITY_CACHE)\n";
            return $item->address;
        }
    }
    # find in point_cache
    foreach my $item (@{$self->{point_cache}}) {
        my $dist = Locator::distance($item->{point}->[0], $item->{point}->[1], $latitude, $longitude);
        if ($dist <= $self->{threshold}) {
            print STDERR __PACKAGE__, " VERY LOW accuracy (POINT_CACHE): $dist \n";
            return $item->{address};
        }
    }
    undef;
}

sub _to_cache
{
    my ($self, $latitude, $longitude, $address) = @_;

    my $city_adr = $address->clone;
    $city_adr->suburb(undef);
    $city_adr->road(undef);
    $city_adr->house(undef);
    $city_adr->postCode(undef);
    
#    print STDERR __PACKAGE__, " try CITY geocode: $city_adr\n";
    my $place;
    eval { $place = $self->{coder}->lookup($city_adr) } if defined $city_adr->city;
#    print STDERR __PACKAGE__, " coder->lookup '", $@, "'\n" if $@;
    if (defined($place && defined($place->geometry) && $place->geometry->is_region)) {
        print STDERR __PACKAGE__, " add to CITY_CACHE ", $place->address->city, "\n";
        push @{$self->{city_cache}}, $place;
    }
    else {
        print STDERR __PACKAGE__, " add to POINT_CACHE\n";
        # fill point_cache
        my $item = {
            point => [$latitude, $longitude],
            address => $city_adr,
        };
        push @{$self->{point_cache}}, $item;
    }
    $city_adr;
}

1;
