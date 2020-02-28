package TypeDefs;

use Scalar::Util;
use Data::Dumper;

#    CodeRef 
#    class_type type
#    class_type from converter class

our @EXPORT = qw(
    Any Defined Undef Ref ArrayRef HashRef 
    Object 
    Str Bool Num Int
    declare typedef as where
    coerce from via
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


#TODO -base -declare -types
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


#############

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
        name        => 'ArrayRef',
        parent      => Ref,
        constraint  => sub { ref $_ eq 'ARRAY' },
    );
}

sub ArrayRef (;$) {
    return _ArrayRef() unless @_;
    my $args = shift;
    my $param = Any;
    $param = typedef($args->[0]) if defined $args->[0]; # and TODO check TYPE
    _croak "Ivalid ArrayRef parameter" unless ref($param) eq __PACKAGE__;
    __PACKAGE__->new(
        name        => 'ArrayRef['.$param->{name}.']', #'__ANON__'
        parent      => _ArrayRef(),
        constraint  => sub { 
            my $array = shift;
            $param->check($_) || return for @$array;
            return !!1;
            },
        converter   => sub { 
            my $arg = shift;
            my $result = [];
#            print "ArrayRef.converter [begin]\n" . Dumper($arg) . "\n\n";
            foreach my $v ( @$arg )
            {
                my $r = $param->convert($v);
#                print "ArrayRef.converter [v]\n" . Dumper($r) . "\n";
                push @$result, $r;
            }
#            print "ArrayRef.converter [end]\n" . Dumper($result) . "\n\n";
            return $result;
            }
#        coercion => sub {
#            my $array = shift;
#            map {$param->convert($_)} for @$array;
#            },
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


#sub type {
#    my $name    = ref($_[0]) ? '__ANON__' : shift;
#    my $coderef = shift;
#    __PACKAGE__->new(
#        name         => $name,
#        constraint   => $coderef,
#    );
#}


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
    
    my $type = $TYPES{$opts{name}} ||= __PACKAGE__->new(%opts);
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


sub coerce
{
    my ($type, @args) = @_;
    $type = typedef($type);
 
    while (@args)
    {
        my $from = typedef(shift @args) || _croak "Invalid type for coercion";
        my $coercion = shift @args;
        _croak "Coercions must be code reference" unless ref $coercion eq 'CODE';
        push @{$type->coercion_map}, $from, $coercion;
    }
#    	return $type->coercion->add_type_coercions(@opts);

}

sub from (@)
{
    return @_;
}

sub via (&;@)
{
    return @_;
}


sub typedef($) {
    my $type = shift || _croak "Requared type name";
    return $type if ref($type) eq __PACKAGE__;
    $TYPES{$type};
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

sub coercion_map { $_[0]{coercion_map} ||= [] };

sub check { 
    my $self = shift;
    my ($value) = @_;
    
    if ($self->{parent}) {
        return unless $self->{parent}->check($value);
    }
    
    local $_ = $value;
    $self->{constraint}->($value);
}

sub convert ($$) {
    my ($self, $value) = @_;
#    print $self->name . '.convert(' . $value . ")\n";
    my @coercions = @{$self->coercion_map};
#    print "\@coercions :\n", Dumper(@coercions), "\n\n";

    # These arrays will be closed over.
    while (@coercions > 1)
    {
        my $from = shift @coercions;
        my $via = shift @coercions;
        if ($from->check($value)) {
#            print '  convert from ' . $from->name . "\n";
            local $_ = $value;
            $value = &$via($_);
#            print '    result ' . $value . "\n";
            return $value;
        }
    }

    if (ref $self->{converter} eq 'CODE') {
        my $func = $self->{converter};
        local $_ = $value;
        return &$func($_);
    }
    if ($self->{parent}) {
        return $self->{parent}->convert($value);
    }
    return $value;
}

sub value($$;$) {
#    print '-' x 20, "\n", Dumper(@_), "\n", '-' x 20, "\n\n";
    my ($self, $value, $name) = @_;
#    return $value unless defined $value;
    $name ||= 'Value';
    #TODO convert value
#    print "BEFORE:\n" . Dumper($value) . "\n\n";
    $value = $self->convert($value);
#    print "AFTER:\n" . Dumper($value) . "\n\n";
    $self->check($value) || _croak $name . ' must be "' . $self->name .'"';
    $value;
}


sub value_from ($\%$) {
    my ($self, $args, $key) = @_;
    
    _croak "Required argument \"$key\"" unless exists $args->{$key};
    
    return $self->value($args->{$key}, "\"$key\"");
}

#sub copy_value($\%\%$) {
#    my ($self, %dest, %src, $key, $requared) = @_;
#    if (exists $src{$key}) {
#        my $value = $src{$key};
#        Rectangle->check($value) || _croak '"' . $key . '" value must be "' . $self->name . '"';
#        $dest{$key} = $self->$value($src{$key} );
#    }
#    else {
#        $requared && _croak '"' . $key . '" is requared';
#    }
#}

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
