package Geo::JSON::Geometry;

#BEGIN
#{
#    require Geo::JSON::Base;
#    push(@ISA, 'Geo::JSON::Base');
#}
use base qw(Geo::JSON::Base);
use Scalar::Util;

#use parent ("Geo::JSON::Base");


sub _init {
    my ($self, $args) = @_;
    if (my(@missing) = grep((!exists $args->{$_}), 'coordinates')) {
        die 'Missing required arguments: ' . join(', ', sort(@missing));
    }
    $self->SUPER::_init($args);
}


sub coordinates
{
    return $_[0]->{coordinates};
}

1;