package Geo::Coder::Base;

use Carp;
#use Geo::JSON;
#use Scalar::Util;
#require TypeDefs;
#use Data::Dumper;
use base Exporter; 
#use Geo::JSON::Types;
#use TypeDefs;


my $_get_sub;

BEGIN
{
    eval { require Net::HTTPS; };
    if ($@) {
#        print __PACKAGE__, " Error Net::HTTPS : $@\n\n";
        my $out = `which curl &>/dev/null && echo OK`;
        chop($out) if defined($out);
#        print __PACKAGE__, " which curl : $out\n\n";
        if ($out eq 'OK') {
#            print __PACKAGE__, " which curl : '$out'\n\n";
            $_get_sub = \&_get_curl;
        }
        else {
#            print __PACKAGE__, " dummy : '$out'\n\n";
            $_get_sub = \&_get_dummy;
        }
    }
    else {
#        print __PACKAGE__, " Net::HTTPS \n";

        require LWP::Simple;

        $_get_sub = \&LWP::Simple::get;
    }
}

sub new 
{
    my $class = ref $_[0] ? ref shift() : shift();

    my $args = scalar @_ == 1 
        ? (ref $_[0] eq 'HASH' 
            ? {%{$_[0];}}
            : croak('Single parameters to new() must be a HASH ref data => ' . $_[0] . "\n")
        )
        : (@_ % 2 
            ? croak("The new() method for $class expects a hash reference or a" 
                . " key/value list. You passed an odd number of arguments\n") 
            : {@_}
        );

    my $new = bless({}, $class);

    $new->_init($args);
    return $new;
}


sub _init 
{
    my ($self, $args) = @_;
}

sub geocode 
{
    croak('Not implemented yet.');
}

# return Geo::Place
sub lookup
{
    my ($self, $address, $language) = @_;
    croak('Not implemented yet.');
}

# return Geo::Address
sub reverse_geocode
{
    my ($self, $latitude, $longitude, $language) = @_;
    croak('Not implemented yet.');
}

sub _get_request()
{
#    print STDERR __PACKAGE__, " _get_request \n";
    my $self = shift;
    return &$_get_sub(@_) if $_get_sub;
    undef;
}

sub _get_curl
{
    my $url = shift;
    eval { $url = $url->abs; } if ref($url) eq 'URI';
    my $out;
#    print __PACKAGE__, " curl -G -k \"$url\" \n";
    $out = `curl -G -k -s "$url"` if defined $url;
#    print __PACKAGE__, " out:'$out' \n";

    $out;
#curl -G -k "https://nominatim.openstreetmap.org/search?format=geojson&polygon_geojson=1&country=Russia&state=Krasnodar%20Krai&city=Adler"
#curl -A "user-agent-name-here" url
#curl --user-agent "user-agent-name-here" url
#curl -H "User-Agent: user-Agent-Name-Here"
}

sub _get_dummy
{
#    print __PACKAGE__, " _get_dummy \n";
    undef;
}

1;