package Template;
use Carp;

use Data::Dumper;

sub parse(&$)
{
    my ($get_value, $str) = @_;
    return unless defined $str;
    return $str if $str  eq '';
    return _parse($str, $get_value);
}


sub validate(&$;\@)
{
    my ($validate_field, $str, $errors) = @_;
    
#    print STDERR __PACKAGE__, " str: '$str'\n";
#    print STDERR __PACKAGE__, " variables", Dumper($variables), "\n\n";
    
    $errors = [] unless ref($errors) eq 'ARRAY';
    @$errors = ();

    # validate field names
    while($str =~ m/\{([^{}]*)\}/og) {
        my $name = $1;
        my $pos = pos($str)-length($name);
#        print "Error in pos: ", $pos, " $name #", length($name), "\n"; # unless exists $value_map{$name};
        #return $pos unless exists $_value_map{$name};
        if (defined($validate_field) 
            && ref $validate_field eq 'CODE') {
            $_ = $name;
            unless (&$validate_field($name)) {
                push(@$errors, {'pos' => $pos, 'text' => $name});
            }
        }
    }
    $str = _replase_or($str);
    while ($str =~ m/([\(\)|%])/og) {
        my $pos = pos($str);
        #print "Error in pos: ", $pos, " $name #", length($name), "\n"; # unless exists $value_map{$name};
        #return $pos;
        push(@$errors, {'pos' => $pos, 'text' => $1});
    }
#    print "X:\n'$str'\n";
    return scalar(@$errors);
}

my $OR_GROUP;
$OR_GROUP = qr{
    \(
    (?:
        ([^()]+)
            |
        (??{$OR_GROUP})
    )*
    \)
}xo;

sub _insert_values($$\$)
{
    my ($str, $get_value, $ref_not_values) = @_;
    my $result = '';
    my $not_values = 0;
    while ($str =~ m/([^{]*)|\{([^{}]*)\}?/g)
    {
        my $text = '';
        my $name = '';
        $text = $1 if defined $1;
        $name = $2 if defined $2;
        $result .= $text;
        if ($name ne '') {
            my $var;
            $_ = $name;
            $var = &$get_value($name) if ref $get_value eq 'CODE';
#            print STDERR __PACKAGE__," get_value($name) = ",(defined($var)? $var : '<UNDEF>' ),"\n";
            $not_values = 1 unless defined $var;
            $result .= $var  if defined $var;
        }
    }
#    print "parse_values: '$str' -> '$result'";
#    print " [" . ref($ref_not_values). "]=" if defined $ref_not_values;
#    print " $not_values" if ref($ref_not_values) eq 'SCALAR';
#    print "\n";
    $$ref_not_values = $not_values if ref($ref_not_values) eq 'SCALAR';
#    print STDERR "ref_not_values: ", ref($ref_not_values), "\n";
#    print STDERR "ref_not_values: $$ref_not_values\n" if ref($ref_not_values) eq 'SCALAR';

    return $result;
}

sub _find_or_group($\$\@\$)
{
    my ($str, $b_ref, $var_ref, $a_ref) = @_;

#    print "b_ref ", ref($b_ref), "\n";
#    print "var_ref ", ref($var_ref), "\n";
#    print "a_ref ", ref($a_ref), "\n";

    if ($str =~ m/$OR_GROUP/g) {
        my $before = $`;
        my $after = $';
        my $substr = substr($&, 1, -1); #$&;
#        print STDERR __PACKAGE__, " Find or: '$str'\n\t'$before'\n\t'$substr'\n\t'$after'\n";
        
#        $substr = $1 if defined $1;
        @$var_ref = () if ref($var_ref) eq 'ARRAY';
        while ($substr =~ m/([^|]*?$OR_GROUP)*[^|]*/g) {
            my $var = $&;
#            print STDERR __PACKAGE__, "  '$var'\n";
#            $var = $1 if defined $1;
            next if $var eq '';
            push @$var_ref, $var if ref($var_ref) eq 'ARRAY';
        }
#        print STDERR __PACKAGE__, " [\n\t".join("\n\t", @$var_ref) . "\n]\n";

        $$b_ref = $before if ref($b_ref) eq 'SCALAR';
        $$a_ref = $after if ref($a_ref) eq 'SCALAR';
#        $$var_ref = $variants if ref($var_ref) eq 'SCALAR';
        return  1;
    }
    return 0;
}


sub _parse($&;\$)
{
    my ($str, $get_value, $ref_not_values) = @_;
    
    my $before;
    my $after;
    my @variants;
    
    return &_insert_values($str, $get_value, $ref_not_values) unless (_find_or_group($str, $before, @variants, $after));
    
    my $result = '';
    $result .= &_insert_values($before, $get_value, $ref_not_values) if $before;
    foreach my $item (@variants) {
        my $not_valid = 0;
        my $var = &_parse($item, $get_value, \$not_valid);
        next unless defined $var;
#        print STDERR "'$item' -> '$var' $not_valid\n";
        next if $not_valid;
        $result .= $var;
        last;
    }
    $result .= &_parse($after, $get_value, $ref_not_values) unless $after eq '';

    return $result;
}


sub _replase_or
{
    my ($str) = @_;
    my $b;
    my $a;
    my @vars;

    return $str unless (_find_or_group($str, $b, @vars, $a));

    my $result = '';
    $result .= $b if defined $b;
    for (my $i = 0; $i < scalar(@vars); $i++) {
#        print "$vars->[$i]\n";
        $vars[$i] = &_replase_or($vars[$i]) if $vars[$i];
    }
    $result .= '[' . join('&', @vars) . ']';
    $a = &_replase_or($a) if defined $a;
    $result .= $a if defined $a;
    return $result;
}

1;
