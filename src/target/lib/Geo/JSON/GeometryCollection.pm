package Geo::JSON::GeometryCollection;

use base qw(Geo::JSON::Geometry);
use TypeDefs;
#use Scalar::Util;

sub _init {
    my ($self, $args) = @_;
#    print "!!! " . __PACKAGE__ . ' - ' . ref ($args) . "\n\n";
#    if (my(@missing) = grep((!exists $args->{$_}), 'coordinates')) {
#        die 'Missing required arguments: ' . join(', ', sort(@missing));
#    }
    $self->SUPER::_init($args);

    if (exists $args->{geometries}) {
        $self->{geometries} = Geometries->value($args->{geometries}, '"geometries"');
    }

}

sub geometries { $_[0]->{geometries} }
#has geometries =>
#    ( is => 'ro', isa => ArrayRef [Geometry], required => 1 );


sub all_positions {
    my $self = shift;

    return [ map { @{ $_->all_positions } } @{ $self->geometries } ];
}

sub inside
{
    my ($self, $point) = @_;
    my $geometries = $self->geometries;
    return undef unless defined $geometries;
    foreach my $geometry ( @{$geometries}) {
        next unless defined $geometry;
        return !!1 if $geometry->inside($point);
    }

    undef;
}

sub beside
{
    my ($self, $point, $distance) = @_;
    my $geometries = $self->geometries;
    return undef unless defined $geometries;
    my $result;
    foreach my $geometry ( @{$geometries}) {
        next unless defined $geometry;
        if (!$result && $geometry->beside($point, $distance)) {
            $result = !!1;
        }
        else {
            return undef if $geometry->inside($point);
        }
    }
    return $result;
}


1;