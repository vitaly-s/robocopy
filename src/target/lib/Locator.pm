package Locator;

use Carp;
use Geo::Address;
use Geo::Place;
use Geo::Coder;
use Geo::JSON::Utils;

use base Exporter; 

#use Geo::JSON::Types;
#use TypeDefs;

sub DEFAULT_THRESHOLD { 1000 }  # 1 km
sub DEFAULT_LANGUAGE { Geo::Coder::DEFAULT_LANGUAGE }

sub new
{
    my $class = ref $_[0] ? ref shift() : shift();

    my $new = bless({}, $class);

    $new->_init(@_);
    
    return $new;
}

sub _init
{
    my $self = $_[0];

    my $coder = $_[1] || create_geocoder();
    
    croak 'The new() method reqiare coder value' unless defined $coder
        && ref $coder
        && UNIVERSAL::isa($coder, 'Geo::Coder::Base');

    $self->{coder} = $coder;
    $self->{language} = DEFAULT_LANGUAGE;
    $self->{threshold} = DEFAULT_THRESHOLD;
#    $self->{point_cache} = [];
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
    my $address;
    my $point;
    if ($query =~ m/([-+]?\d{1,2}\.\d+)\s*,\s*([-+]?\d{1,2}\.\d+)/) {
        $point = {
            latitude => 0.0 + $1,
            longitude => 0.0 + $2,
        };
        eval { $address = $self->{coder}->reverse($point->{latitude}, $point->{longitude}, $self->{language}) };
#       print STDERR __PACKAGE__, " coder->reverse '", $@, "'\n" if $@;
    }
    else {
        my $place;
        eval { $place = $self->{coder}->search($query, $self->{language}) };
#       print STDERR __PACKAGE__, " coder->search '", $@, "'\n" if $@;
        if (defined $place) {
#            print STDERR __PACKAGE__, " coder->search 'address': ", ref($place->address), "\n";
#           print STDERR __PACKAGE__, " coder->search 'geometry': ", ref($place->geometry), "\n";
            $address = $place->address;
            if (defined($place->geometry) && ref($place->geometry) eq 'Geo::JSON::Point') {
                $point = {
                    latitude => $place->geometry->coordinates->[1],
                    longitude => $place->geometry->coordinates->[0],
                };
            }
#            print STDERR __PACKAGE__, " address ", join(',', keys %{$adress}), "\n";
        }
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
    my $address = $self->_from_cache($latitude, $longitude);
    return $address if defined $address;

#    print STDERR __PACKAGE__, " try geocode\n";
    eval { $address = $self->{coder}->reverse($latitude, $longitude, $self->{language}) };
    
    return unless defined $address;
    
    # put to cache
    return $self->_to_cache($latitude, $longitude, $address);
}

sub _from_cache
{
#    my ($self, $latitude, $longitude) = @_;
#    foreach my $item (@{$self->{point_cache}}) {
#        my $dist = distance($item->{point}->[0], $item->{point}->[1], $latitude, $longitude);
#        if ($dist <= $self->{threshold}) {
##            print STDERR __PACKAGE__, " VERY LOW accuracy (POINT_CACHE): $dist \n";
#            return $item->{address};
#        }
#    }
    undef;
}

sub _to_cache
{
    my ($self, $latitude, $longitude, $address) = @_;
#    my $item = {
#        point => [$latitude, $longitude],
#        address => $address,
#    };
##    print STDERR __PACKAGE__, " add to POINT_CACHE\n";
#    push @{$self->{point_cache}}, $item;
    $address;
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
