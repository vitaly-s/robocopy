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
#    my $language = $_[1];
    
    croak 'The new() method reqiare coder value' unless defined $coder
        && ref $coder
        && $coder->isa('Geo::Coder::Base');

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

sub locate
{
    my ($self, $latitude, $longitude) = @_;
    return unless defined $latitude and defined $longitude;
    # find in cache
    foreach my $item (@{$self->{cache}}) {
        next unless defined $item && ref $item eq 'HASH' && defined $item->{place};
#        print STDERR __PACKAGE__, " check INBOX '", $item->{place}->displayName, "'\n";
#        print STDERR __PACKAGE__, '  bbox: ', Str->convert($item->{place}->bbox), "\n" if defined($item->{place}->bbox);
        next unless $item->{place}->in_bbox($longitude, $latitude);
        my $geometry = $item->{place}->geometry;
        if (defined($geometry) && $geometry->is_region) {
            next unless $geometry->inside([$longitude, $latitude]);
#            print STDERR __PACKAGE__, " HIGH accuracy (cache)\n";
            return $item->{place}->address;
        }
#        if (defined $item->{city} && $item->{city}->geometry->inside([$longitude, $latitude])) {
#            print STDERR __PACKAGE__, " LOW accuracy (cache)\n";
#            return $item->{place}->address;
#        }
    }
    # find in invalid cache
    foreach my $item (@{$self->{invalid_cache}}) {
        my $dist = distance($item->{point}->[0], $item->{point}->[1], $latitude, $longitude);
        if ($dist <= $self->{threshold}) {
#            print STDERR __PACKAGE__, " VERY LOW accuracy (invalid_cache): $dist \n";
            return $item->{address};
        }
    }

#    print STDERR __PACKAGE__, " try CITY geocode\n";
    my $place;
    eval { $place = $self->{coder}->reverse($latitude, $longitude, Geo::Coder::ACCURACY_CITY, $self->{language}, 1) };
#    print STDERR __PACKAGE__, " coder->reverse '", $@, "'\n" if $@;
    if (defined($place) && defined($place->address)) {
#        print STDERR __PACKAGE__, " located place '",$place->displayName, "'\n";
        if (defined($place->address->city)
            && defined($place->geometry) && $place->geometry->is_region)
        {
#            print STDERR __PACKAGE__, " add to CHACHE\n";
            my $new_item = {place => $place};
#            if (defined($place->address->suburb) || defined($place->address->road)) {
#    #            print STDERR __PACKAGE__, " try lookup city\n";
#                my $city_adr = $place->address->clone();
#                $city_adr->suburb(undef);
#                #$city_adr->street(undef);
#                my $city;
#                eval {$city = $self->{coder}->lookup($city_adr, $self->{language})};
#                $new_item->{city} = $city if defined $city && $city->geometry->is_region;
#            }
            push @{$self->{cache}}, $new_item;
            
            return $place->address;
        }
    }
    else {
#        print STDERR __PACKAGE__, " try COUNTRY geocode\n";
        eval { $place = $self->{coder}->reverse($latitude, $longitude, 
            Geo::Coder::ACCURACY_COUNTRY, $self->{language}) };
#        print STDERR __PACKAGE__, " located place '",$place->displayName, "'\n" if defined $place;
    }
    if (defined $place) {
#        print STDERR __PACKAGE__, " add to INVALID_CHACHE\n";
        # fill invalid_cache
        my $invalid_item = {
            point => [$latitude, $longitude],
            address => $place->address,
        };
        push @{$self->{invalid_cache}}, $invalid_item;
        
        return $place->address;
    }
    undef;
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
