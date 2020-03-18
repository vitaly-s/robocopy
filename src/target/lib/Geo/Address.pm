package Geo::Address;

use Carp;
#use base Exporter;

BEGIN
{
    use TypeDefs 
    qw(
        Address
    );
    
    declare Address,
        as Object,
        where { $_->isa(__PACKAGE__)};
        
    coerce Address,
        from HashRef, via { Geo::Address->new($_) };
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

    foreach my $key (qw(country countryCode state county city postCode subLocality street type)) {
        next unless defined $args->{$key};
        $new->$key($args->{$key});
        undef $empty;
    }

    return $new;
}

sub is_empty
{
    my ($self, $value) = @_;
}

sub country
{
    my ($self, $value) = @_;
    $self->{country} = $value if defined $value;
    $self->{country};
}

sub countryCode
{
    my ($self, $value) = @_;
    $self->{countryCode} = $value if defined $value;
    $self->{countryCode};
}

sub state
{
    my ($self, $value) = @_;
    $self->{state} = $value if defined $value;
    $self->{state};
}

sub county
{
    my ($self, $value) = @_;
    $self->{county} = $value if defined $value;
    $self->{county};
}


sub postCode
{
    my ($self, $value) = @_;
    $self->{postCode} = $value if defined $value;
    $self->{postCode};
}

sub city
{
    my ($self, $value) = @_;
    $self->{city} = $value if defined $value;
    $self->{city};
}

sub subLocality
{
    my ($self, $value) = @_;
    $self->{subLocality} = $value if defined $value;
    $self->{subLocality};
}


sub street
{
    my ($self, $value) = @_;
    $self->{street} = $value if defined $value;
    $self->{street};
}

sub type
{
    my ($self, $value) = @_;
    $self->{type} = $value if defined $value;
    $self->{type};
}

1;