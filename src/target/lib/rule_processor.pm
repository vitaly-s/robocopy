#!/usr/bin/perl
#
# @File rule_processor.pm
# @Author vitalys
# @Created Sep 6, 2016 8:52:33 AM
#

package rule_processor;

use strict;
use utf8;
use Encode;
use File::Basename;
use File::Find;
use File::Spec::Functions;
use File::Path;
use File::Compare;
use File::Copy;
#    use File::stat;
use POSIX qw(strftime);
use Time::Local;
use HTTP::Date;
use Data::Dumper;


BEGIN {
    # get exe directory
    my $scriptDir = dirname($0);

    unshift @INC, "$scriptDir";
} 

use Image::ExifTool qw(:Public);    
use Syno;

my $writed_file;

sub new {
    my($class, $rule) = @_;
    
#        print 'ref rule: ' . ref($rule) . "\n";
    
    $rule = {} unless ref($rule) eq 'HASH' || ref($rule) eq 'rule';
    # создаем хэш
    my $self = { };

    foreach my $key (keys %{$rule}) {
        $self->{$key} = $rule->{$key};
    }

    # хэш превращается, превращается... в объект
    bless $self, $class;
   
    return $self;
}

sub dest_dir {
    my $self = shift;
    return '{file_dir}' unless defined $self->{dest_dir} && $self->{dest_dir} ne '';
    return $self->{dest_dir};
}

sub dest_file {
    my $self = shift;
    return '{file_name}' unless defined $self->{dest_file} && $self->{dest_file} ne '';
    return $self->{dest_file};
}

sub dest_ext {
    my $self = shift;
    return '{file_ext}' unless defined $self->{dest_ext} && $self->{dest_ext} ne '';
    return $self->{dest_ext};
}

sub description {
    my $self = shift;
    return $self->{description} if defined $self->{description};
    return '#' . $self->{priority} . ' [' .$self->{id}. ']';
}

sub is_prepared {
    my $self = shift;
    return 0 unless defined $self->{src_mask};
    return 0 unless defined $self->{dest_path};
    return 0 unless defined $self->{src_path};
    
    return 1;
}

sub src_path {
    my $self = shift;
    return $self->{src_path};
}

sub prepared_path
{
    my $self = shift;
    return $self->{prepared_path} if defined $self->{prepared_path};
    return $self->{src_path};
}

sub user {
    my ($self, $value) = @_;
    if (defined($value)) {
        $self->{user} = $value;
        my ($user_uid, $user_gid);
        (undef, undef, $user_uid, $user_gid) = getpwnam($value);
        $self->{user_uid} = $user_uid;
        $self->{user_gid} = $user_gid;
    }
    return undef unless defined $self->{user};
    return $self->{user};
}


my %_field_map = (
    'type' => ['MIMEType'],
    'date' => ['DateTimeOriginal', 'CreateDate', 'ModifyDate', 'MediaModifyDate', 'CreationDate', 'MediaCreateDate', 'FileModifyDate'],
    'title' => ['DisplayName', 'Title', 'Title2'],
    'album' => ['Album', 'Album2'],
    'artist' => ['Artist', 'Artist2'],
#    'track' => ['Track'], # audio track number
#    'genre' => ['Genre'], # audio style: 'Disco', 'Jazz', 'Rock' and other....
    'camera_make' => ['Make'],
    'camera_model' => ['Model'],
#    'file_name' => ['OriginalFileName'],
    'latitude' => ['GPSLatitude'],
    'longitude' => ['GPSLongitude'],
);

my %_field_parser = (
    'date' => \&str2time,
    'latitude' => \&_parse_float,
    'longitude' => \&_parse_float,
    'title' => \&_parse_str,
    'album' => \&_parse_str,
    'artist' => \&_parse_str,
    'camera_make' => \&_parse_str,
    'camera_model' => \&_parse_str,
);

my %_value_map = (
    #time
    'h' => sub { return _get_date_value($_[0], '%I')+0; },  #hours 0-12
    'hh' => sub { return _get_date_value($_[0], '%I'); },   #hours 00-12
    'H' => sub { return _get_date_value($_[0], '%H')+0; },  # hours 0-23
    'HH' => sub { return _get_date_value($_[0], '%H'); },   # hours 00-23
    'm' => sub { return _get_date_value($_[0], '%M')+0; },  # minutes 0-59
    'mm' => sub { return _get_date_value($_[0], '%M'); },   # minutes 00-59
    's' => sub { return _get_date_value($_[0], '%S')+0; },  # seconds 0-59
    'ss' => sub { return _get_date_value($_[0], '%S'); },   # seconds 00-59
    'tt' => sub { return _get_date_value($_[0], '%p'); },   # AM/PM
    #date
    'd' => sub { return _get_date_value($_[0], '%d')+0; },  #day 1-31
    'dd' => sub { return _get_date_value($_[0], '%d'); },   #day 01-31
    'ddd' => sub { return _get_date_value($_[0], '%a'); },  #mon
    'dddd' => sub { return _get_date_value($_[0], '%A'); }, #Monday
    'M' => sub { return _get_date_value($_[0], '%m')+0; },  # month 1-12
    'MM' => sub { return _get_date_value($_[0], '%m'); },   # month 01-12
    'MMM' => sub { return _get_date_value($_[0], '%b'); },  # month Jan
    'MMMM' => sub { return _get_date_value($_[0], '%B'); }, # month Januare
    'y' => sub { return _get_date_value($_[0], '%y')+0; },  # year 0-99
    'yy' => sub { return _get_date_value($_[0], '%y'); },   # year 00-99
    'yyyy' => sub { return _get_date_value($_[0], '%Y'); }, # year 0000-9999
    #other
    'title' => \&_get_info_value,
    'album' => \&_get_info_value,
    'artist' => \&_get_info_value,
    'camera_make' => \&_get_info_value,
    'camera_model' => \&_get_info_value,
    #file
    'file_ext' => \&_get_info_value,
    'file_dir' => \&_get_info_value,
    'file_name' => \&_get_info_value,
    #location
#   'country' => \&get_location,
#   'state' => \&get_location,
#   'city' => \&get_location,
);

sub _get_date_value(\%$)
{
    my ($info, $fmt) = @_;
    return undef unless defined $fmt;
    return undef unless exists $info->{date};
    return strftime($fmt, localtime($info->{date}));
}

sub _get_info_value(\%$)
{
    my ($info, $name) = @_;
    return undef unless defined $name;
    return undef unless exists $info->{$name};
    return $info->{$name};
}

sub _find_address($$)
{
    my ($lat,$lon) = @_;
    return undef unless defined $lat;
    return undef unless defined $lon;
    print "*** call GEOCODER:\n\t";
    print "https://nominatim.openstreetmap.org/reverse?format=geojson&lat=$lat&lon=$lon&polygon_geojson=1&zoom=14";
    print "\n";
# get geometry: Point, Region, MultiPolygon
#    https://nominatim.openstreetmap.org/search?format=geojson&polygon_geojson=1&country=Russia&state=<state>&city=<city>
    return { country => 'RU' };

}

sub _get_location(\%$)
{
    my ($info, $name) = @_;
    return undef unless defined $name;
    unless (exists $info->{location}) {
        $info->{location} = find_address($info->{latitude}, $info->{longitude});
    }
    return undef unless exists $info->{location};
    return $info->{location}->{$name};
}

sub _parse_float($)
{
    return $_[0] + 0;
}

sub _parse_str($)
{
    utf8::decode($_[0]) unless utf8::is_utf8($_[0]);
    $_[0] =~ s/^\s+|\s+$//g;
    return $_[0];
}
sub get_file_info($$\%)
{
    my ($self, $file, $info) = @_;
    
    return undef unless defined $file;
    return undef unless ref($info) eq 'HASH';
    return undef unless -f $file;

    
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(DateFormat => '%Y-%m-%d %H:%M:%S', CoordFormat => '%+.6f', Exclude => ['ThumbnailImage']);
    #'%Y-%m-%d %H:%M:%S%z'

    $exifTool->ExtractInfo($file);

    foreach my $key (keys %_field_map) {
        my $map = $_field_map{$key};
        my $parser = $_field_parser{$key};
        my $value;
#        print STDERR "$key:\n";
        foreach my $prop (@$map) {
            $value = $exifTool->GetValue($prop);
            next unless defined $value;
 #           print STDERR "\t$prop: $value\n";
            $value = $parser->($value) if defined $parser;
            last if defined $value;
        }
        $info->{$key} = $value if defined $value;
    }
    # correct file date
    $info->{date} = (stat($file))[9] unless exists $info->{date};
    # get file names
    my($file_name, $file_dir, $suffix) = fileparse($file, qr/\.[^.]*/);
    $info->{file_ext} = substr($suffix, 1) if defined $suffix;
    $file_dir = substr($file_dir, length($self->{src_path})) if defined $self->{src_path};
    $info->{file_dir} = $file_dir if defined $file_dir;
    $info->{file_name} = $file_name if defined $file_name;

    return $info->{date};
}

sub get_value(\%$)
{
    my ($info, $name) = @_;
    return undef unless ref($info) eq 'HASH';
    return undef unless exists $_value_map{$name};
#    return $value_map{$name} if ref($_value_map{$name}) eq 'SCALAR';
    return $_value_map{$name}->($info, $name) if ref($_value_map{$name}) eq 'CODE';
#    print "$name -> ", ref($value_map{$name}), "\n";
    return $_value_map{$name};
}

my $_or_group;
$_or_group = qr{
    \(
    (
    (?:
        (?>[^()]+)
        |
        (??{$_or_group})
    )*
    )
    \)
}xo;

sub _insert_values($;\%\$)
{
    my ($str, $info, $ref_not_values) = @_;
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
            $var = get_value(%$info, $name);
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

    if ($str =~ m/([^\(\)]*)$_or_group(.*)/) {
        my $before = $1; #$`;
        my $after = $3; #$';
        my $substr = $2; #$&;
#        $substr = $1 if defined $1;
        @$var_ref = () if ref($var_ref) eq 'ARRAY';
        while ($substr =~ m/([^|]*$_or_group+[^|]*|[^|]*)/og) {
            my $var = $1; #$&;
#            $var = $1 if defined $1;
            next if $var eq '';
            push @$var_ref, $var if ref($var_ref) eq 'ARRAY';
        }
#        print "[".join(",", @$variants) . "]\n";

        $$b_ref = $before if ref($b_ref) eq 'SCALAR';
        $$a_ref = $after if ref($a_ref) eq 'SCALAR';
#        $$var_ref = $variants if ref($var_ref) eq 'SCALAR';
        return  1;
    }
    return 0;
}

sub _parse($;\%\$)
{
    my ($str, $info, $ref_not_values) = @_;
    
    my $before;
    my $after;
    my @variants;
    
    return &_insert_values($str, $info, $ref_not_values) unless (_find_or_group($str, $before, @variants, $after));
    
    my $result = '';
    $result .= &_insert_values($before, $info, $ref_not_values) if $before;
    foreach my $item (@variants) {
        my $not_valid = 0;
        my $var = &_parse($item, $info, \$not_valid);
        next unless defined $var;
#        print STDERR "'$item' -> '$var' $not_valid\n";
        next if $not_valid;
        $result .= $var;
        last;
    }
    $result .= &_parse($after, $info, $ref_not_values) unless $after eq '';

    return $result;
}

sub parse_template($;\%)
{
    my ($str, $info) = @_;
    return undef unless defined $str;
    return $str if $str  eq '';
    return _parse($str, %$info);
}

sub _replase_or($)
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

# return count of errors
sub validate_template($;\@)
{
    my ($str, $errors) = @_;
    
    $errors = [] unless ref($errors) eq 'ARRAY';
    @$errors = ();
    # validate field names
    while($str =~ m/\{([^{}]*)\}/og) {
        my $name = $1;
        my $pos = pos($str)-length($name);
#        print "Error in pos: ", $pos, " $name #", length($name), "\n"; # unless exists $value_map{$name};
        #return $pos unless exists $_value_map{$name};
        push(@$errors, {'pos' => $pos, 'text' => $name}) unless exists $_value_map{$name};
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

sub prepare($$;\$) {
    my $tmp_error;
    my($self, $dir, $error) = @_;
    
#        print 'ref error: ' . ref($error) . "\n";
    $error = \$tmp_error unless ref($error) eq 'SCALAR';

    my $src_ext = $self->{src_ext};
    $src_ext = '*' if !defined($src_ext) || $src_ext eq '';
    $self->{src_mask} = $src_ext eq '*' ? '(\..*?|)$' : "\.$src_ext\$";

    my $syno_folder = Syno::share_path($self->{'dest_folder'});
    unless (defined $syno_folder) {
        $$error = "Invalid destination share name: \"$self->{dest_folder}\".";
        return 0;
    }
    my $dest_path = catfile($syno_folder, $self->dest_dir(), $self->dest_file() . '.' . $self->dest_ext());
    if (validate_template($dest_path)) {
        $$error = "Invalid template for destination file name: \"$dest_path\".";
        return 0;
    }
    $self->{dest_path} = $dest_path;

#        if ($dir =~ /^@(\w+)/) {
#            # replace share name
#            my $share_name = $1;
#            my $share_path = Syno::share_path($share_name);
#            next unless defined $share_path;
#            $dir =~ s/[@]$share_name/$share_path/;
#        }
    my $src_path = catdir($dir);
    my $src_dir = $self->{src_dir};
    $src_path = catdir($src_path, $src_dir) if defined $src_dir;
    $self->{src_path} = $src_path;
    $self->{prepared_path} = $dir;
    
    return 1;
}


sub find_files(;\$)
{
    my @files = ();
    my ($self, $total_size) = @_;
    $$total_size = 0 if ref($total_size) eq 'SCALAR';

    
    if ($self->is_prepared()) {
        my $src_path = $self->{src_path};

        if ( -d $src_path) {
#                   print "\t$src_path\n" if $verbose;
            find sub {
                # Skip @eaDir folders
                if (-d && /\@eaDir/) {
                    $File::Find::prune = 1;
                    return;
                }
                my $file_name = $_;
                utf8::decode($file_name) unless utf8::is_utf8($file_name);
                my $file_dir = $File::Find::dir;
                utf8::decode($file_dir) unless utf8::is_utf8($file_dir);
                my $file_path = catfile($file_dir, $file_name);
#                    print STDERR "0: '$_'" . (utf8::is_utf8($_) ? "[UTF8]" : "[bytes]") . "\n";
                if ( -f "$file_name" && $file_name =~ /$self->{src_mask}/i) { 
#                        print STDERR "1: '$file_path" . (utf8::is_utf8($file_path) ? "[UTF8]" : "[bytes]") . "\n";
                    push @files, $file_path;
                    if (ref($total_size) eq 'SCALAR') {
                        my $file_size = -s "$file_path";
#                            $file_size = (stat $file_name)[7] unless defined $file_size;
                        print STDERR "Cannot get file size for '$file_path'\n" unless defined $file_size;
                        $$total_size += $file_size if defined $file_size;
                    }
                } 
            }, $src_path;
        }
    }
    return (wantarray ? @files : \@files);
}

sub make_dest_file($$;\$)
{
    my ($self, $file, $ref_file_time) = @_;

#    print STDERR Dumper(\@_), "\n";
    # Make output file name
    my %info = ();
    my $file_time = $self->get_file_info($file, \%info);
    return undef unless defined $file_time;
#    print STDERR " Date '" . basename($file) . "' = " . strftime('%Y-%m-%d %H:%M:%S', localtime($file_time)) . "\n";
    $$ref_file_time = $file_time if ref($ref_file_time) eq 'SCALAR';
#    print STDERR "\t => ". strftime('%Y-%m-%d %H:%M:%S', localtime($$ref_file_time)) ."\n" if ref($ref_file_time) eq 'SCALAR';
    my $dest_file = parse_template($self->{dest_path}, %info);
#    print STDERR "0: '$self->{dest_path}'" . (utf8::is_utf8($self->{dest_path}) ? "[UTF8]" : "[bytes]") . "\n";
    utf8::decode($dest_file) unless utf8::is_utf8($dest_file);
#    print STDERR "1: '$dest_file'" . (utf8::is_utf8($dest_file) ? "[UTF8]" : "[bytes]") . "\n";
    $dest_file = canonpath($dest_file);
#    print STDERR "2: '$dest_file'" . (utf8::is_utf8($dest_file) ? "[UTF8]" : "[bytes]") . "\n";
    return $dest_file;
}

sub process_file($$;\$)
{
    my $tmp_error;
    my ($self, $file, $error) = @_;
    $error = \$tmp_error unless ref($error) eq 'SCALAR';

    unless (-f $file) {
        $$error = "File \"$file\" not found";
        return 0;
    }

    my $src_remove = $self->{src_remove};
    $src_remove = 0 unless defined $src_remove;


    my $file_time;
    my $dest_file = $self->make_dest_file($file, \$file_time);
    unless (defined $dest_file) {
        $$error = "Cannot make destination file for \"$file\"";
        return 0;
    }
#        print "\t\t$file -> $dest_file\n" if $verbose;
    # Create destination dir
    my @created = mkpath(dirname($dest_file), 0, 0755);
    chown $self->{user_uid}, $self->{user_gid}, @created if defined($self->{user_uid}) && defined ($self->{user_gid});

    if (-d $dest_file) {
        $$error = "Cannot overwrite directory \"$dest_file\"";
        return 0;
    }
    elsif (-f $dest_file) {
        if (compare($file, $dest_file) == 1) {
            $$error = "Cannot overwrite file \"$dest_file\", because it not identical to \"$file\"";
            return 0;
        }
        elsif ($src_remove) {
            unless (unlink($file)) { 
                $$error = "Cannot delete file \"$file\"";
                return 0;
            }
        }
    }
    else {
#            local $SIG{KILL} = \&cleanup;
        $writed_file = $dest_file;
        if ($src_remove) {
            unless (rename($file, $dest_file)) {
                $$error = "Cannot move file \"$file\" to \"$dest_file\"";
                return 0;
            }
        }
        else {
            unless (copy($file, $dest_file)) {
                $$error = "Cannot copy file \"$file\" to \"$dest_file\"";
                return 0;
            }
            chown $self->{user_uid}, $self->{user_gid}, ($dest_file) if defined($self->{user_uid}) && defined ($self->{user_gid});
        }
        utime($file_time, $file_time, $dest_file);
        undef $writed_file;
    }
    return 1;
}

sub cleanup
{
    unlink($writed_file) if defined $writed_file && -f $writed_file;
}

sub END
{
    cleanup;
}

1;
