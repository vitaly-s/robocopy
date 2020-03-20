package Locator;

use Carp;
use Geo::Address;
use Geo::Place;
use Geo::JSON::Utils;


#use Geo::JSON::Types;
#use TypeDefs;

sub new
{
    my $class = ref $_[0] ? ref shift() : shift();

    my $coder = $_[0];
    my $language = $_[1];
    
    croak 'The new() method reqiare coder value' unless defined $coder
        && ref $coder
        && $coder->isa('Geo::Coder::Base');

    my $new = bless({
        coder => $coder,
        language => $language,
        cache => [],
    }, $class);

    return $new;
}

sub locate
{
    my ($self, $latitude, $longitude) = @_;
    return undef unless defined $latitude;
    return undef unless defined $longitude;
    # use cache
    foreach my $item (@{$self->{cache}}) {
        next unless defined $item && ref $item eq 'HASH' && defined $item->{place};
#        print STDERR __PACKAGE__, " check INBOX '", $item->{place}->displayName, "'\n";
#        print STDERR __PACKAGE__, '  bbox: ', Str->convert($item->{place}->bbox), "\n" if defined($item->{place}->bbox);
        next unless $item->{place}->in_bbox($longitude, $latitude);
        my $geometry = $item->{place}->geometry;
        if (defined($geometry) && $geometry->is_region) {
            next unless $geometry->inside([$longitude, $latitude]);
#            print STDERR __PACKAGE__, " HIGH accuracy (cached)\n";
            return $item->{place}->address;
        }
        if (defined $item->{city} && $item->{city}->geometry->inside([$longitude, $latitude])) {
#            print STDERR __PACKAGE__, " LOW accuracy (cached)\n";
            return $item->{place}->address;
        }
    }
#    print STDERR __PACKAGE__, " try geocode\n";
    my $address;
    eval { $address = $self->{coder}->reverse_geocode($latitude, $longitude, $self->{language}) };
    return unless defined $address;
#    print STDERR __PACKAGE__, " located city '",$address->city, "'\n";
    # fill cache
    my $place;
    eval { $place = $self->{coder}->lookup($address, $self->{language}) };
    if (defined $place) {
#        print STDERR __PACKAGE__, " located place '",$place->displayName, "'\n";
        my $new_item = {place => $place};
        if (defined($address->subLocality) || defined($address->street)) {
#            print STDERR __PACKAGE__, " try lookup city\n";
            my $type = ref($address);
            my $city_adr =  bless {%$address}, $type;
            $city_adr->subLocality(undef);
            $city_adr->street(undef);
            my $city;
            eval {$city = $self->{coder}->lookup($city_adr, $self->{language})};
            $new_item->{city} = $city if defined $city && $city->geometry->is_region;
        }
        push @{$self->{cache}}, $new_item;
    }
    return $address;
}

1;
