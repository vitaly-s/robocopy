package Geo::JSON::Base;

use Carp;
use Geo::JSON;
use Scalar::Util;
#require TypeDefs;
use Data::Dumper;
#BEGIN
#{
#  our @EXPORT = ( ); # you may even omit this line 
  use base Exporter; 
#  our @ISA = qw(Exporter);
#}
use Geo::JSON::Types;
use TypeDefs;


sub new {
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


sub _init {
    my ($self, $args) = @_;
    if (exists $args->{bbox}) {
        my $value = $args->{bbox};
        Rectangle->check($value) || croak "'bbox' value must be 'Rectangle'";
        $self->{bbox} = $value;
    }
}

sub type
{
    ( ( ref $_[0] ) =~ m/::(\w+)$/ )[0];
}

sub to_json {
    my $self = shift;
    my $codec = shift || $Geo::JSON::json_codec;
    return $codec->encode($self);
}

# used by JSON 'convert_blessed'
sub TO_JSON {
    return { type => $_[0]->type, %{ $_[0] } };
}


sub bbox(;\@)
{
    my $self = $_[0];
#    $self->{bbox} = $_[1] if ref($_[1]) eq 'ARRAY';
    $self->{bbox};
}

sub all_positions
{
    return shift->coordinates;
}

sub compute_bbox
{
    return Geo::JSON::Utils::compute_bbox( shift->all_positions );
}

1;