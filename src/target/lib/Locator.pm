package Locator;

use Carp;
use Geo::Address;
use Geo::Place;
use Geo::Coder;
use Geo::JSON::Utils;


#use Geo::JSON::Types;
#use TypeDefs;

sub DEFAULT_THRESHOLD { 1000 }
sub DEFAULT_LANGUAGE { Geo::Coder::DEFAULT_LANGUAGE }


sub new
{
    my $class = ref $_[0] ? ref shift() : shift();

    my $coder = $_[0] || create_geocoder();
    
    croak 'The new() method reqiare coder value' unless defined $coder
        && ref $coder
        && UNIVERSAL::isa($coder, 'Geo::Coder::Base');

    my $new = bless({
        coder => $coder,
        language => DEFAULT_LANGUAGE,
        threshold => DEFAULT_THRESHOLD, # 1 km
        cache => [],
        invalid_cache => [],
    }, $class);

    return $new;
}

sub language
{
    my $self = shift;
    my $old = $self->{language};
    if (@_) {
        $self->{language} = shift;
    }
    return $old;
}

sub threshold
{
    my $self = shift;
    my $old = $self->{threshold};
    if (@_) {
        $self->{threshold} = shift;
    }
    return $old;
}

sub search($$)
{
    my ($self, $query) = @_;
    return unless defined $query;
    my $place;
    eval { $place = $self->{coder}->search($query, $self->{language}) };
#    print STDERR __PACKAGE__, " coder->search '", $@, "'\n" if $@;
    my $address;
    my $point;
    if (defined $place) {
#        print STDERR __PACKAGE__, " coder->search 'address': ", ref($place->address), "\n";
#        print STDERR __PACKAGE__, " coder->search 'geometry': ", ref($place->geometry), "\n";
        $address = $place->address;
        if (defined($place->geometry) && ref($place->geometry) eq 'Geo::JSON::Point') {
            $point = {
                latitude => $place->geometry->coordinates->[1],
                longitude => $place->geometry->coordinates->[0],
            };
        }
#        print STDERR __PACKAGE__, " address ", join(',', keys %{$adress}), "\n";
    }
    if (wantarray) {
        return ($address, $point);
    }
    return $address;
}

sub locate($$$)
{
    my ($self, $latitude, $longitude) = @_;
    return unless defined $latitude and defined $longitude;
    # find in cache
    foreach my $item (@{$self->{cache}}) {
        next unless $item->in_bbox($longitude, $latitude);
        my $geometry = $item->geometry;
        if (defined($geometry) && $geometry->is_region) {
            next unless $geometry->inside([$longitude, $latitude]);
#            print STDERR __PACKAGE__, " HIGH accuracy (cache)\n";
            return $item->address;
        }
    }
    # find in invalid cache
    foreach my $item (@{$self->{invalid_cache}}) {
        my $dist = distance($item->{point}->[0], $item->{point}->[1], $latitude, $longitude);
        if ($dist <= $self->{threshold}) {
#            print STDERR __PACKAGE__, " VERY LOW accuracy (invalid_cache): $dist \n";
            return $item->{address};
        }
    }

#    print STDERR __PACKAGE__, " try geocode\n";
    my $address;
    eval { $address = $self->{coder}->reverse($latitude, $longitude, $self->{language}) };
    
    return unless defined $address;
    
    my $city_adr = $address->clone;
    $city_adr->suburb(undef);
    $city_adr->road(undef);
    $city_adr->house(undef);
    $city_adr->postCode(undef);
    
#    print STDERR __PACKAGE__, " try CITY geocode\n";
    my $place;
    eval { $place = $self->{coder}->lookup($city_adr) } if defined $city_adr->city;
#    print STDERR __PACKAGE__, " coder->reverse '", $@, "'\n" if $@;
    if (defined($place && defined($place->geometry) && $place->geometry->is_region)) {
#        print STDERR __PACKAGE__, " add to CHACHE ", $place->address->city, "\n";
        push @{$self->{cache}}, $place;
    }
    else {
#        print STDERR __PACKAGE__, " add to INVALID_CHACHE\n";
        # fill invalid_cache
        my $invalid_item = {
            point => [$latitude, $longitude],
            address => $city_adr,
        };
        push @{$self->{invalid_cache}}, $invalid_item;
    }
    $city_adr;
}

# See:
#   https://stackoverflow.com/questions/15736995/how-can-i-quickly-estimate-the-distance-between-two-latitude-longitude-points
#   https://stackoverflow.com/questions/27928/calculate-distance-between-two-latitude-longitude-points-haversine-formula
sub distance
{
    my ($lat1, $lon1, $lat2, $lon2) = map { $_ * 0.017453292519943295 } @_;
    return unless defined $lat1 && defined $lat2 && defined $lon1 && defined $lon2;
    
    my $radius = 6371000;  # radius of the earth in m
    my $x = ($lon2 - $lon1) * cos(0.5 * ($lat2 + $lat1));
    my $y = $lat2 - $lat1;
    $radius * sqrt($x * $x + $y * $y);
}

#sub pi { 3.141592653589793 }
#sub pi_180 { 0.017453292519943295 }

#sub PI() { 4 * atan2(1, 1) }

#sub deg2rad($)
#{
#  $_[0] * 0.017453292519943295; #(Math.PI/180)
#}


1;
