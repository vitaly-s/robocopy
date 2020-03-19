package Geo::Coder::Base;

use Carp;
use base Exporter; 

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
    
    $self->{agent} = $args->{agent} || 'perl-lib/Geo::Coder';
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

sub agent($)
{
    $_[0]->{agent};
}


my $_get_sub;

sub get_request
{
    $_get_sub ||= do {
        if (eval {
            require Net::HTTPS;
            require LWP::UserAgent;
        }) {
#            print STDERR __PACKAGE__, " Init LWP client\n\n";
            \&_get_lwp;
        }
        else {
            my $out = `which curl &>/dev/null && echo OK`;
            chop($out) if defined($out);
            if ($out eq 'OK') {
#                print STDERR __PACKAGE__, " Init CURL client\n\n";
                \&_get_curl;
            }
            else {
                \&_get_dummy;
            }
        }
    };
#    print STDERR __PACKAGE__, " _get_request \n";
    return &$_get_sub(@_);
}



sub _get_lwp
{
    my ($self, $url) = @_;
#    print __PACKAGE__, " _lwp_get \n";
    
    $self->{ua} ||= do {
            my $ua = LWP::UserAgent->new;
            $ua->agent($self->agent);
            $ua->env_proxy;
            $ua;
        };
    my $response = $self->{ua}->get($url);
    return $response->decoded_content if $response->is_success;
    undef;
}

sub _get_curl
{
    my ($self, $url) = @_;
    eval { $url = $url->abs; } if ref($url) eq 'URI';
    my $agent = $self->agent;
    my $out;
#    print __PACKAGE__, " curl -G -k \"$url\" \n";
    $out = `curl -A "$agent" -G -k -s "$url"` if defined $url;
#    print __PACKAGE__, " out:'$out' \n";

    $out;
}

sub _get_dummy
{
#    print __PACKAGE__, " _get_dummy \n";
    undef;
}

1;
