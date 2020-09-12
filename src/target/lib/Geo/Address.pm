package Geo::Address;

use Carp;
#use base Exporter;

use overload q("") => \&as_string,
    q(==) => \&equal_to,
    q(!=) => sub { !shift->equal_to(shift); };

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

    foreach my $key (qw(country countryCode state county city postCode suburb road house type)) {
        next unless defined $args->{$key};
        $new->$key($args->{$key});
        undef $empty;
    }

    return $new;
}

sub clone
{
    my $self = shift;
    my $type = ref $self;
    return bless {%$self}, $type;
}

sub is_empty
{
    my ($self, $value) = @_;
}

sub country
{
    my $self = shift;
    my $old_value = $self->{country};
    if (@_) {
        $self->{country} = shift;
    }
    $old_value;
}

sub countryCode
{
    my $self = shift;
    my $old_value = $self->{countryCode};
    if (@_) {
        $self->{countryCode} = shift;
    }
    $old_value;
}

sub state
{
    my $self = shift;
    my $old_value = $self->{state};
    if (@_) {
        $self->{state} = shift;
    }
    $old_value;
}

sub county
{
    my $self = shift;
    my $old_value = $self->{county};
    if (@_) {
        $self->{county} = shift;
    }
    $old_value;
}


sub postCode
{
    my $self = shift;
    my $old_value = $self->{postCode};
    if (@_) {
        $self->{postCode} = shift;
    }
    $old_value;
}

sub city
{
    my $self = shift;
    my $old_value = $self->{city};
    if (@_) {
        $self->{city} = shift;
    }
    $old_value;
}

sub suburb
{
    my $self = shift;
    my $old_value = $self->{suburb};
    if (@_) {
        $self->{suburb} = shift;
    }
    $old_value;
}

sub road
{
    my $self = shift;
    my $old_value = $self->{road};
    if (@_) {
        $self->{road} = shift;
    }
    $old_value;
}

sub house
{
    my $self = shift;
    my $old_value = $self->{house};
    if (@_) {
        $self->{house} = shift;
    }
    $old_value;
}

sub type
{
    my $self = shift;
    my $old_value = $self->{type};
    if (@_) {
        $self->{type} = shift;
    }
    $old_value;
}


sub TO_JSON {
    return { %{ shift() } };
}

sub as_string
{
    my $self = shift;
    return join (', ', grep( { defined $_ } map { $self->{$_} } qw/ house road suburb city county state postCode country / ));
}

sub equal_to
{
    my ($a, $b) = @_;
    
    return 0 unless defined $a
        && defined $b
        && UNIVERSAL::isa($a, __PACKAGE__)
        && UNIVERSAL::isa($b, __PACKAGE__)
        && scalar(keys %$a) == scalar(keys %$b);

    foreach my $key (keys %$a) {
        return 0 unless defined($a->{$key}) == defined($b->{$key});
        next unless defined($a->{$key});
        return 0 unless $a->{$key} eq $b->{$key};
    }
    return !!1;
}


1;
