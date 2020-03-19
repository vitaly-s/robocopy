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
    my $old_value = $self->{country};
    $self->{country} = $value if defined $value;
    $old_value;
}

sub countryCode
{
    my ($self, $value) = @_;
    my $old_value = $self->{countryCode};
    $self->{countryCode} = $value if defined $value;
    $old_value;
}

sub state
{
    my ($self, $value) = @_;
    my $old_value = $self->{state};
    $self->{state} = $value if defined $value;
    $old_value;
}

sub county
{
    my ($self, $value) = @_;
    my $old_value = $self->{county};
    $self->{county} = $value if defined $value;
    $old_value;
}


sub postCode
{
    my ($self, $value) = @_;
    my $old_value = $self->{postCode};
    $self->{postCode} = $value if defined $value;
    $old_value;
}

sub city
{
    my ($self, $value) = @_;
    my $old_value = $self->{city};
    $self->{city} = $value if defined $value;
    $old_value;
}

sub subLocality
{
    my ($self, $value) = @_;
    my $old_value = $self->{subLocality};
    $self->{subLocality} = $value if defined $value;
    $old_value;
}


sub street
{
    my ($self, $value) = @_;
    my $old_value = $self->{street};
    $self->{street} = $value if defined $value;
    $old_value;
}

sub type
{
    my ($self, $value) = @_;
    my $old_value = $self->{type};
    $self->{type} = $value if defined $value;
    $old_value;
}

1;
