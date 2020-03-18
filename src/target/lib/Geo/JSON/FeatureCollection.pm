package Geo::JSON::FeatureCollection;

use base qw(Geo::JSON::Base);
#use Scalar::Util;
use TypeDefs;

sub _init {
    my ($self, $args) = @_;
#    if (my(@missing) = grep((!exists $args->{$_}), 'coordinates')) {
#        die 'Missing required arguments: ' . join(', ', sort(@missing));
#    }
    $self->SUPER::_init($args);

    $self->{features} = Features->value_from('features', $args);
}


sub features { shift->{features} }

sub all_positions {
    my $self = shift;

    return [ map { @{ $_->all_positions } } @{ $self->features } ];
}

1;