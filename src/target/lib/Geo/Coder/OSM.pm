package Geo::Coder::OSM;

use Carp;
use base qw(Geo::Coder::Base);
use Geo::JSON;
require Geo::Address;
require Geo::Place;
require Geo::Coder;

use URI;


sub _init 
{
    my ($self, $args) = @_;
    $self->SUPER::_init($args);
}

#our %SOURCES = (
#    osm      => 'http://nominatim.openstreetmap.org',
#    mapquest => 'http://open.mapquestapi.com/nominatim/v1',
#);

sub SOURCE { 'https://nominatim.openstreetmap.org' }

sub lookup
{
    my ($self, $address, $language) = @_;
    croak "Invalid parametr 'address': " . (defined $address ? $address : "<UNDEF>") unless defined $address
        && ref $address
        && $address->isa('Geo::Address');

    my %data = (
        'format'          => 'geojson',
        'polygon_geojson' => 1,
        'addressdetails'  => 1,
        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
    );
    $data{country} = $address->country if defined $address->country;
    $data{state} = $address->state if defined $address->state;
    $data{county} = $address->county if defined $address->county;
    $data{city} = $address->city if defined $address->city;
    $data{city} = $address->subLocality if defined $address->subLocality;
    #street=<housenumber> <streetname>
    $data{postalcode} = $address->postCode if defined $address->postCode;
    
    $uri = URI->new(SOURCE . '/search');
    $uri->query_form(%data);
#    print STDERR "\t", __PACKAGE__, " GET 1 ", Dumper($uri), " \n";
    $context = $self->get_request($uri);
    next undef unless defined $context;
    my $features = Geo::JSON::from_json($context)->features;

    return unless ref $features eq 'ARRAY' && @$features > 0;
    my $feature = $features->[0];

    my %place;
    $place{bbox} = $feature->bbox if defined $feature->bbox;
    $place{geometry} = $feature->geometry if defined $feature->geometry;
    $place{displayName} = $feature->properties->{display_name} if ref $feature->properties eq 'HASH' && defined $feature->properties->{display_name};
    $place{address} = parse_feature_address($feature) || $address;

    return Geo::Place->new(%place);
}

sub reverse_geocode
{
    my ($self, $latitude, $longitude, $language) = @_;
    my $uri = URI->new(SOURCE . '/reverse');
    $uri->query_form(
        'lat'             => $latitude,
        'lon'             => $longitude,
        'format'          => 'geojson',
        'addressdetails'  => 1,
        'zoom'            => 14,
        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
    );

    my $context = $self->get_request($uri);
    
    return unless defined $context;
#    print STDERR __PACKAGE__, "-context: $context \n";
    my $features = Geo::JSON::from_json($context)->features;
    return unless ref $features eq 'ARRAY' && @$features > 0;
    return parse_feature_address($features->[0]);
}

sub parse_feature_address($)
{
    my $feature = shift;
    
    return unless defined $feature
        && defined $feature->properties
        && ref $feature->properties eq 'HASH'
        && defined $feature->properties->{address}
        && ref $feature->properties->{address} eq 'HASH';

    my $address = $feature->properties->{address};

    my %data;
    $data{country} = $address->{country} if defined $address->{country};
    $data{countryCode} = $address->{country_code} if defined $address->{country_code};
    $data{state} = $address->{state} if defined $address->{state};
    $data{county} = $address->{county} if defined $address->{county};
    $data{postCode} = $address->{postcode} if defined $address->{postcode};
    if (defined $address->{city}) {
        $data{city} = $address->{city};
        $data{type} = 'city';
        $data{subLocality} = $address->{suburb} if defined $address->{suburb};
    }
    elsif (defined $address->{town}) {
        $data{city} = $address->{town};
        $data{type} = 'town';
    }
    elsif (defined $address->{village}) {
        $data{city} = $address->{village};
        $data{type} = 'village';
    }
    elsif (defined $address->{hamlet}) {
        $data{city} = $address->{hamlet};
        $data{type} = 'hamlet';
    }
    return Geo::Address->new(%data);
}

1;
