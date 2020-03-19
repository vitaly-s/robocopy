package Geo::Place;

use Carp;
use base Exporter; 
use Geo::JSON::Types;
use TypeDefs;
use Geo::Address;

#use Data::Dumper;

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

#    print "  ", __PACKAGE__, Dumper($args), "\n";

    if (exists $args->{displayName}) {
        $new->{displayName} = Str->value_from('displayName', $args);
    }

    if (exists $args->{bbox}) {
        $new->{bbox} = Rectangle->value_from('bbox', $args);
    }

    if (exists $args->{geometry}) {
        $new->{geometry} = Geometry->value_from('geometry', $args);
    }

    if (exists $args->{address}) {
        $new->{address} = Address->value_from('address', $args);
    }

    return $new;
}


sub address
{
    my ($self, $value) = @_;
#    $self->{address} = Address->value($value) if defined $value;
    $self->{address} ||= Geo::Address->new();
    $self->{address};
}

sub geometry 
{ 
    shift->{geometry} 
}

sub bbox
{
    my $self = $_[0];
#    $self->{bbox} = $_[1] if ref($_[1]) eq 'ARRAY';
    $self->{bbox};
}

sub displayName
{
    my $self = $_[0];
    $self->{name};
}

1;
