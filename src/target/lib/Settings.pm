package Settings;

use strict;
use Carp;
use JSON::XS;

require Locator;


sub SETTING_FILE { '/var/packages/robocopy/etc/settings.conf' }


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
    my $new = bless({
            locator_threshold => $args->{locator_threshold} || Locator::DEFAULT_THRESHOLD,
            locator_language => $args->{locator_language} || Locator::DEFAULT_LANGUAGE,
        } , $class);
    return $new;
}

sub locator_threshold 
{
    my $self = shift;
    my $old = $self->{locator_threshold};
    if (@_) {
        $self->{locator_threshold} = shift;
    }
    $old;
}

sub locator_language 
{
    my $self = shift;
    my $old = $self->{locator_language};
    if (@_) {
        $self->{locator_language} = shift;
    }
    $old;
}

sub load(;$)
{
    my $file = shift;
    $file = SETTING_FILE unless defined $file;

    
    unless (-f $file) {
        return __PACKAGE__->new();
    }
    my $text = do {
        local $/ = undef;
        open my $fh, "<", $file || croak "Could not open $file: $!";
        <$fh>;
    };
    
    my $data = JSON::XS->new->utf8->decode($text);
    return __PACKAGE__->new($data);
#    return bless $data, __PACKAGE__; 
}

sub save(&;$)
{
    my ($self, $file) = @_;
    $file = SETTING_FILE unless defined $file;
    open my $fh, ">", $file || croak "Could not open $file: $!";
    print $fh JSON::XS->new->utf8->convert_blessed->encode($self);
    close $fh;
}

sub TO_JSON {
    return { %{ shift() } };
}


1;
