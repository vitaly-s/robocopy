package TypeDefs;

#use strict;
#use warnings;
use Scalar::Util;
#use Data::Dumper;

#use base qw(Exporter);
#require Exporter;

#our @ISA = qw(Exporter);

#our @EXPORT_OK = qw/ compare_positions compute_bbox /;
#    CodeRef Object 
#    class_type type

our @EXPORT = qw(
    Any Defined Undef Ref ArrayRef HashRef 
    Str Bool Num Int
    declare typedef as where
);

our %TYPES;

sub _croak { require Carp; goto \&Carp::croak }
sub _carp { require Carp; goto \&Carp::carp }

sub mk_get_type_name($) {
    my $name = shift;
    return sub { 
#        print "get soft '$name'\n";
#        typedef($name) || 
        $name 
    };
}

sub mk_get_type($) {
    my $name = shift;
    return sub { 
#        print "get hard '$name'\n";
        typedef($name) || _croak "'$name' not defined" 
    };
}

#BEGIN {
#    my $caller = caller(0);
#    print "!!! BEGIN " . __PACKAGE__ . "($caller)\n";
#}

#END {
#    my $caller = caller(0);
#    print "!!! END " . __PACKAGE__ . "($caller)\n";
#}

sub import {
#    use strict;
#    no strict 'refs';
    my $pkg = shift || __PACKAGE__;
    my $callpkg = caller(0);

#    print '#' x 20, "\nIMPORT($callpkg -> $pkg):\n\n";
    # export base types from @EXPORT
    foreach my $func (@EXPORT) {
#        print "$callpkg\::$func => $pkg\::$func;\n";
        *{$callpkg . '::' . $func} = \&{$pkg . '::'. $func };
    }    
    
    # export types from %TYPES
    foreach my $type (sort keys %TYPES) {
        unless ( grep { $_ eq $type } @EXPORT ) {
#            print "$callpkg\::$type => $pkg\::$type;\n"; 
            *{$callpkg . '::' . $type} = mk_get_type($type);
#            $\&{$pkg . '::'. $type }; # TODO source ???
        }
    }
    # export predefined types from @_
    foreach my $def (@_) {
        *{$callpkg . '::' . $def} = mk_get_type_name($def);
#        my $func_int = mk_get_type_name($def);
    }
}


#########
sub declare
{
#    print '#' x 20, "\nTYPEDEF:\n", Dumper(@_), "\n",scalar @_, "\n", '#' x 20, "\n\n\n";
    my %opts;
    if (@_ % 2 == 0)
    {
        %opts = @_;
        if (@_==2 and $_[0]=~ /^_*[A-Z]/ and $_[1] =~ /^[0-9]+$/)
        {
            _carp("Possible missing comma after 'declare $_[0]'");
        }
    }
    else
    {
        (my($name), %opts) = @_;
        _croak "Cannot provide two names for type" if exists $opts{name};
        $opts{name} = $name;
    }
    
    my $caller = caller; #($opts{_caller_level} || 0);
    $opts{library} = $caller;

    if (defined $opts{parent}) {
        $opts{parent} = typedef($opts{parent}) 
            || _croak 'Invalid parent "' . $opts{parent}  . '" for type "' . $opts{name} . '"';
    }

#    if (defined $opts{parent})
#    {
#        $opts{parent} = to_TypeTiny($opts{parent});
#        
#        unless (TypeTiny->check($opts{parent}))
#        {
#            $caller->isa("Type::Library")
#                or _croak("Parent type cannot be a %s", ref($opts{parent})||'non-reference scalar');
#            $opts{parent} = $caller->meta->get_type($opts{parent})
#                or _croak("Could not find parent type");
#        }
#    }
    
    my $type = $TYPES{$opts{name}} ||= __PACKAGE__->new(%opts);

#    if (defined $opts{parent})
#    {
#        $type = delete($opts{parent})->create_child_type(%opts);
#    }
#    else
#    {
#        my $bless = delete($opts{bless}) || "Type::Tiny";
#        eval "require $bless";
#        $type = $bless->new(%opts);
#    }
    
#    if ($caller->isa("Type::Library"))
#    {
#        $caller->meta->add_type($type) unless $type->is_anon;
#    }
    
#    return $type;
#    print '#' x 20, "\nTYPEDEF:\n", Dumper($type), "\n",scalar @_, "\n", '#' x 20, "\n\n\n";

#    my $func = sub {
#        $TYPES{$opts{name}} ||= $type;
#    };
#    *{$type->name} = \&$func;

}



sub as (@)
{
#    print '-' x 20, "\nAS:\n", Dumper(@_), "\n", '-' x 20, "\n\n";
    parent => @_;
}

sub where (&;@)
{
#    print '-' x 20, "\nWHERE:\n", Dumper(@_), "\n", '-' x 20, "\n\n";
    constraint => @_;
}

sub message (&;@)
{
    message => @_;
}


sub typedef($) {
    my $type = shift || _croak "Requared type name";
    return $type if ref($type) eq __PACKAGE__;
    $TYPES{$type};
}



sub Any () {
    $TYPES{Any} ||= __PACKAGE__->new(
        name         => 'Any',
        constraint   => sub { !!1 },
    );
}

sub Defined () {
    $TYPES{Defined} ||= __PACKAGE__->new(
        name         => 'Defined',
        parent       => Any,
        constraint   => sub { defined $_ },
    );
}

sub Undef () {
    $TYPES{Undef} ||= __PACKAGE__->new(
        name         => 'Undef',
        parent       => Any,
        constraint   => sub { !defined $_ },
    );
}

sub Ref () {
    $TYPES{Ref} ||= __PACKAGE__->new(
        name         => 'Ref',
        parent       => Defined,
        constraint   => sub { ref $_ },
    );
}

sub _ArrayRef () {
#    print '-' x 20, "\nArrayRef:\n", Dumper(@_), "\n", '-' x 20, "\n\n";
    $TYPES{ArrayRef} ||= __PACKAGE__->new(
        name         => 'ArrayRef',
        parent       => Ref,
        constraint   => sub { ref $_ eq 'ARRAY' },
    );
}

sub ArrayRef ($) {
    return _ArrayRef() unless @_;
    my $args = shift;
#    print '-' x 20, "\nArrayRef():\n", Dumper(@_), "\n", '-' x 20, "\n\n";
#    print '-' x 20, "\nArrayRef():\n", Dumper($args), "\n", '-' x 20, "\n\n";
    my $param = Any;
    $param = typedef($args->[0]) if defined $args->[0]; # and TODO check TYPE
#     print '-' x 20, "\nArrayRef (",ref($param),"):\n", Dumper($param), "\n", '-' x 20, "\n\n";
    _croak "Ivalid ArrayRef parameter" unless ref($param) eq __PACKAGE__;
#    my $min = $_[1] if defined $_[1];
#    my $max = $_[2] if defined $_[2];
    #$TYPES{ArrayRef} ||= 
    __PACKAGE__->new(
        name        => 'ArrayRef['.$param->{name}.']',
        parent      => _ArrayRef(),
#        param       => $param,
        constraint  => sub { 
            my $array = shift;
            $param->check($_) || return for @$array;
            return !!1;
            },
    );
}


sub HashRef () {
    $TYPES{HashRef} ||= __PACKAGE__->new(
        name         => 'HashRef',
        parent       => Ref,
        constraint   => sub { ref $_ eq 'HASH' },
    );
}

sub CodeRef () {
    $TYPES{CodeRef} ||= __PACKAGE__->new(
        name         => 'CodeRef',
        parent       => Ref,
        constraint   => sub { ref $_ eq 'CODE' },
    );
}

sub Object () {
    $TYPES{Object} ||= __PACKAGE__->new(
        name         => 'Object',
        parent       => Ref,
        constraint   => sub { Scalar::Util::blessed($_) },
    );
}

sub Bool () {
    $TYPES{Bool} ||= __PACKAGE__->new(
        name         => 'Bool',
        parent       => Any,
        constraint   => sub { !defined($_) or (!ref($_) and { 1 => 1, 0 => 1, '' => 1 }->{$_}) },
    );
}

sub Str () {
    $TYPES{Str} ||= __PACKAGE__->new(
        name         => 'Str',
        parent       => Defined,
        constraint   => sub { !ref $_ },
    );
}

sub Num () {
    $TYPES{Num} ||= __PACKAGE__->new(
        name         => 'Num',
        parent       => Str,
        constraint   => sub { Scalar::Util::looks_like_number($_) },
    );
}

sub Int () {
    $TYPES{Int} ||= __PACKAGE__->new(
        name         => 'Int',
        parent       => Num,
        constraint   => sub { /\A-?[0-9]+\z/ },
    );
}

sub class_type ($) {
    my $class = shift;
    $TYPES{CLASS}{$class} ||= __PACKAGE__->new(
        name         => $class,
        parent       => Object,
        constraint   => sub { $_->isa($class) },
        class        => $class,
    );
}

sub type {
    my $name    = ref($_[0]) ? '__ANON__' : shift;
    my $coderef = shift;
    __PACKAGE__->new(
        name         => $name,
        constraint   => $coderef,
    );
}

#########
sub new { 
    my $class = ref($_[0]) ? ref(shift) : shift;
    my $self  = bless { @_ == 1 ? %{+shift} : @_ } => $class;
    
    $self->{constraint} ||= sub { !!1 };
    unless ($self->{name}) {
        require Carp;
        Carp::croak("Requires both `name` and `constraint`");
    }
    
    $self;
}

sub check { 
    my $self = shift;
    my ($value) = @_;
    
    if ($self->{parent}) {
        return unless $self->{parent}->check($value);
    }
    
    local $_ = $value;
    $self->{constraint}->($value);
}

#sub get_message { 
#    my $self = shift;
#    my ($value) = @_;
    
#    require B;
#    !defined($value)
#        ? sprintf("Undef did not pass type constraint %s", $self->{name})
#        : ref($value)
#            ? sprintf("Reference %s did not pass type constraint %s", $value, $self->{name})
#            : sprintf("Value %s did not pass type constraint %s", B::perlstring($value), $self->{name});
#}

sub name {
    shift->{name};
}

1;
