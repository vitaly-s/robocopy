package Geo::Coder::OSM;

use Carp;
use base qw(Geo::Coder::Base);
use Geo::JSON;
require Geo::Address;
require Geo::Place;
require Geo::Coder;

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

sub ZOOM_COUNTRY { 3 }
sub ZOOM_STATE   { 5 }
sub ZOOM_CITY    { 14 }
sub ZOOM_HOUSE   { 18 }

my @VALID_KEYS_COUNTRY = qw(country country_code);
my @VALID_KEYS_STATE = ( @VALID_KEYS_COUNTRY, qw(state) );
my @VALID_KEYS_CITY = ( @VALID_KEYS_STATE, qw(postcode city town village hamlet) );

#print STDERR __PACKAGE__, "" ,Dumper(@VALID_KEYS_CITY), "\n\n";

my %ACCURACY_MAP = (
    Geo::Coder::ACCURACY_COUNTRY  => { 
        zoom => ZOOM_COUNTRY, 
        categories => [ 'boundary' ],
        valid_keys => \@VALID_KEYS_COUNTRY,
#        clear_keys => [],
    },
    Geo::Coder::ACCURACY_STATE    => { 
        zoom => ZOOM_STATE, 
        categories => [ 'boundary' ],
        valid_keys => \@VALID_KEYS_STATE,
#        clear_keys => ['state', 'postcode'],
    },
    Geo::Coder::ACCURACY_CITY     => { 
        zoom => ZOOM_CITY, 
        categories => [ 'place' ],
        valid_keys => \@VALID_KEYS_CITY,
#        clear_keys => [ qw( county city town village hamlet suburb ) ],
    },
    Geo::Coder::ACCURACY_HOUSE    => { 
        zoom => ZOOM_HOUSE, 
        categories => [ 'place', 'building', 'highway' ],
#        clear_keys => ['road', 'house_number'],
    },
);

my %INVALID_KEYS = (
    'city' => ['town', 'village', 'hamlet', 'suburb'],
    'town' => ['city', 'village', 'hamlet', 'suburb'],
    'village' => ['city', 'town', 'hamlet', 'suburb'],
    'hamlet' => ['city', 'town', 'village', 'suburb'],
    'suburb' => ['town', 'village', 'hamlet'],
);

my %DELETE_KEYS = (
);

sub reverse
{
    my ($self, $latitude, $longitude, $accuracy, $language, $geometry) = @_;
    $accuracy = Geo::Coder::DEFAULT_ACCURACY unless defined $accuracy;
#    $geometry = 1 unless defined $geometry;
    my $args = $ACCURACY_MAP{$accuracy};
    croak "Required parameter: latitude" unless defined $latitude;
    croak "Required parameter: longitude" unless defined $longitude;
#    croak "Invalid parameter: accuracy" unless defined $accuracy;
#    print STDERR __PACKAGE__, " reverse - args($accuracy):", Dumper($args), "\n";

    my $uri = URI->new(SOURCE . '/reverse');
    my %common_args = (
        'format'          => 'geojson',
        'polygon_geojson' => 1,
        'addressdetails'  => 1,
        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
    );
    $common_args{polygon_geojson} = 1 if $geometry;
    
    $uri->query_form(((
        'lat'             => $latitude,
        'lon'             => $longitude,
        'zoom'            => $args->{zoom},
        ),
        %common_args)
    );
#    print STDERR __PACKAGE__, " reverse - send: $uri \n";

    my $context = $self->get_request($uri);
    
    return unless defined $context;
#    print STDERR __PACKAGE__, "-context: $context \n";
    my $features = Geo::JSON::from_json($context)->features;
    return unless ref $features eq 'ARRAY' && @$features > 0 
        && defined $features->[0] && defined $features->[0]->{properties}
        && ref $features->[0]->{properties} eq 'HASH'
        && defined $features->[0]->{properties}->{category}
        && defined $features->[0]->{properties}->{address}
        && ref $features->[0]->{properties}->{address} eq 'HASH';
        
    my $feature = $features->[0];
    my $invalid_key = $INVALID_KEYS{$feature->{properties}->{type}} || [];
    my $invalid = grep { exists $feature->{properties}->{address}->{$_} } @{$invalid_key};
    my $valid_keys = 0;
    $valid_keys = grep { not exists $feature->{properties}->{address}->{$_} } @{$args->{valid_keys}} 
        if defined $args->{valid_keys};
#    print STDERR __PACKAGE__, "-invalid: ", Dumper($invalid), "\n";
#    print STDERR __PACKAGE__, "-valid_keys: ", Dumper($valid_keys), "\n";
    unless (grep {$_ eq $feature->{properties}->{category}} @{$args->{categories}}
        && ($invalid == 0) && ($valid_keys == 0)) {
#        print STDERR __PACKAGE__, " need update: ", $feature->{properties}->{category}, '/',$accuracy," \n";
        my $address = $feature->{properties}->{address};
        my %data = %common_args;
        if ($args->{zoom} >= ZOOM_COUNTRY) {
            $data{country} = $address->{country} if defined $address->{country};
        }
        if ($args->{zoom} >= ZOOM_STATE) {
            $data{state} = $address->{state} if defined $address->{state};
        }
        if ($args->{zoom} >= ZOOM_CITY) {
            $data{county} = $address->{county} if defined $address->{county};
            $data{postalcode} = $address->{postcode} if defined $address->{postcode};
            if (defined $address->{city}) {
                $data{city} = $address->{city};
            }
            elsif (defined $address->{town}) {
                $data{city} = $address->{town};
            }
            elsif (defined $address->{village}) {
                $data{city} = $address->{village};
            }
            elsif (defined $address->{hamlet}) {
                $data{city} = $address->{hamlet};
            }
        }
        if ($args->{zoom} >= ZOOM_HOUSE) {
            $data{city} = $address->{suburb} if defined $address->{suburb};
            my $street = join ' ', grep { defined $_ } $adress->{house_number}, $address->{road};
            $data{street} = $street if $street;
        }

        $uri = URI->new(SOURCE . '/search');
        $uri->query_form(%data);
#        print STDERR __PACKAGE__, " reverse - send 2: $uri \n";
        $context = $self->get_request($uri);
        if (defined $context) {
#            print STDERR __PACKAGE__, "-context 1: $context \n";
            $features = Geo::JSON::from_json($context)->features;

            $feature = $features->[0] if ref $features eq 'ARRAY' && @$features > 0;
            unless (grep {$_ eq $feature->{properties}->{category}} @{$args->{categories}} ) {
#                print STDERR __PACKAGE__, " NOT FOUND: ", " \n";
#                return;
                delete $feature->{geometry};
                delete $feature->{bbox};
                my $place = parse_feature($feature);
                if ($args->{zoom} <= ZOOM_COUNTRY) {
                    $place->address->country(undef);
                    $place->address->countryCode(undef);
                }
                if ($args->{zoom} <= ZOOM_STATE) {
                    $place->address->state(undef);
                    $place->address->county(undef);
                }
                if ($args->{zoom} <= ZOOM_CITY) {
                    $place->address->city(undef);
                    $place->address->suburb(undef);
                    $place->address->type(undef);
                }
                if ($args->{zoom} <= ZOOM_HOUSE) {
                    $place->address->road(undef);
                    $place->address->house(undef);
                }
#                print STDERR __PACKAGE__, " Not found ", Dumper($place), " \n";
                return $place;
#                foreach my $key (@{$args->{clear_keys}}) {
#                    delete $feature->{properties}->{address}->{$key}; # if exists $feature->{properties}->{address}->{$key};
#                }
            }
        }
    }
    
    #properties->category == place
    return parse_feature($feature);
}

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
    $data{city} = $address->suburb if defined $address->suburb;
    #street=<housenumber> <streetname>
    $data{postalcode} = $address->postCode if defined $address->postCode;
    
    my $uri = URI->new(SOURCE . '/search');
    $uri->query_form(%data);
#    print STDERR "\t", __PACKAGE__, " GET 1 ", Dumper($uri), " \n";
    my $context = $self->get_request($uri);
    next undef unless defined $context;
    my $features = Geo::JSON::from_json($context)->features;

    return unless ref $features eq 'ARRAY' && @$features > 0;

    return parse_feature($features->[0]);
}


#sub reverse_geocode
#{
#    my ($self, $latitude, $longitude, $language) = @_;
#    my $uri = URI->new(SOURCE . '/reverse');
#    $uri->query_form(
#        'lat'             => $latitude,
#        'lon'             => $longitude,
#        'format'          => 'geojson',
#        'addressdetails'  => 1,
#        'zoom'            => 14,
#        'accept-language' => $language || Geo::Coder::DEFAULT_LANGUAGE,
#    );
#
#    my $context = $self->get_request($uri);
#    
#    return unless defined $context;
##    print STDERR __PACKAGE__, "-context: $context \n";
#    my $features = Geo::JSON::from_json($context)->features;
#    return unless ref $features eq 'ARRAY' && @$features > 0;
#    #properties->category == place
#    return parse_feature_address($features->[0]);
#}

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
