package Geo::Coder::OSM;

use Carp;
use base qw(Geo::Coder::Base);
use Geo::JSON;
require Geo::Address;
require Geo::Coder;
use JSON::XS qw/ /;

use URI;

use Data::Dumper;


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

#print STDERR __PACKAGE__, "" ,Dumper(@VALID_KEYS_CITY), "\n\n";


sub reverse
{
    my ($self, $latitude, $longitude, $language) = @_;
    croak "Required parameter: latitude" unless defined $latitude;
    croak "Required parameter: longitude" unless defined $longitude;
#    print STDERR __PACKAGE__, " reverse - args($accuracy):", Dumper($args), "\n";

    my $uri = URI->new(SOURCE . '/reverse');
    my %common_args = (
        'format'          => 'json',
        'addressdetails'  => 1,
        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
    );
    $common_args{polygon_geojson} = 1 if $geometry;
    
    $uri->query_form({
        'format'          => 'geojson',
        'addressdetails'  => 1,
        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
        'lat'             => $latitude,
        'lon'             => $longitude,
        'zoom'            => 18,
    });
#    print STDERR __PACKAGE__, " reverse - send: $uri \n";

    my $context = $self->get_request($uri);
    
    return unless defined $context;
#    print STDERR __PACKAGE__, "-context: $context \n";

    my $features = Geo::JSON::from_json($context)->features;
    
    return unless ref $features eq 'ARRAY' 
        && @$features > 0
        && defined $features->[0]
        && defined $features->[0]->properties
        && ref $features->[0]->properties eq 'HASH';

    delete $features->[0]->properties->{address}->{city} if defined $features->[0]->properties->{category}
        && $features->[0]->properties->{category} eq 'boundary';
#    my $data = JSON::XS->new->utf8->decode($context);
#    return unless ref $data eq 'HASH'
#        && exists $data->{address};

    return parse_address($features->[0]->properties->{address});
}


sub lookup
{
    my ($self, $address) = @_;

    my $feature = $self->_lookup_address($address);
    
    return unless defined $feature;
    
    my %place;
    $place{bbox} = $feature->bbox if defined $feature->bbox;
    $place{geometry} = $feature->geometry if defined $feature->geometry; # && $feature->geometry->is_region;
    $place{displayName} = $feature->properties->{display_name} if ref $feature->properties eq 'HASH' 
        && defined $feature->properties->{display_name};
    $place{address} = $address;

    return Geo::Place->new(%place);

}


sub _lookup_address
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
    $data{city} = $address->suburb if defined $address->suburb;
    $data{postalcode} = $address->postCode if defined $address->postCode;
    #street=<housenumber> <streetname>
    my $street = join ' ', grep { defined $_ } $adress->{house_number}, $address->{road};
    $data{street} = $street if $street;
    
    my $uri = URI->new(SOURCE . '/search');
    $uri->query_form(%data);
#    print STDERR "\t", __PACKAGE__, " GET 1 ", Dumper($uri), " \n";
    my $context = $self->get_request($uri);
    next undef unless defined $context;
    my $features = Geo::JSON::from_json($context)->features;
    
    return unless ref $features eq 'ARRAY' 
        && @$features > 0;

    $features->[0];
}

sub parse_address($)
{
    my $address = shift;
    
    return unless defined $address
        && ref $address eq 'HASH';

    my %data;
    $data{country} = $address->{country} if defined $address->{country};
    $data{countryCode} = $address->{country_code} if defined $address->{country_code};
    $data{state} = $address->{state} if defined $address->{state};
    $data{county} = $address->{county} if defined $address->{county};
    $data{postCode} = $address->{postcode} if defined $address->{postcode};
    if (defined $address->{city}) {
        $data{city} = $address->{city};
        $data{type} = 'city';
        $data{suburb} = $address->{suburb} if defined $address->{suburb};
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
    if (defined $address->{road}) {
        $data{road} = $address->{road};
        $data{type} = 'road' unless defined $data{type};
    }
    $data{house} = $address->{house_number} if defined $address->{house_number};
    
    return Geo::Address->new(%data);
}




########
sub parse_feature($)
{
    my $feature = shift;

    my %place;
    $place{bbox} = $feature->bbox if defined $feature->bbox;
    $place{geometry} = $feature->geometry if defined $feature->geometry;
    $place{displayName} = $feature->properties->{display_name} if ref $feature->properties eq 'HASH' 
        && defined $feature->properties->{display_name};
    $place{address} = parse_feature_address($feature) || $address;

    return Geo::Place->new(%place);
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
        $data{suburb} = $address->{suburb} if defined $address->{suburb};
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
    if (defined $address->{road}) {
        $data{road} = $address->{road};
        $data{type} = 'road' unless defined $data{type};
    }
    $data{house} = $address->{house_number} if defined $address->{house_number};
    
    return Geo::Address->new(%data);
}

1;
