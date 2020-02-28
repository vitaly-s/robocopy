package Geo::JSON::Feature;

use base qw(Geo::JSON::Base);
#use Scalar::Util;
use TypeDefs;


sub _init {
    my ($self, $args) = @_;
#    if (my(@missing) = grep((!exists $args->{$_}), 'coordinates')) {
#        die 'Missing required arguments: ' . join(', ', sort(@missing));
#    }
    $self->SUPER::_init($args);
    
    $self->{id} = $args->{id};
    
    $self->{geometry} = Geometry->value_from($args, 'geometry');
    
    if (exists $args->{properties} ) {
        $self->{properties} = HashRef->value_from($args, 'properties');
    }

}

sub id { shift->{id} }

sub geometry { shift->{geometry} }

sub properties { shift->{properties} }

sub all_positions 
{
    return shift->geometry->all_positions;
}

1;