package FileInfo;

#use 5.008;
#use strict;
use warnings;

use Carp;
use strict;
use utf8;
use Encode;
use File::Basename;
use File::Spec::Functions;
use POSIX qw(strftime);
use Time::Local;
use HTTP::Date;
use Data::Dumper;

use Locator;
use Template;

use Image::ExifTool qw(:Public);    

my %FIELD_MAP;
my %FIELD_PARSER;
my %VALUE_MAP;

sub load($;$)
{
    my $class = __PACKAGE__; #ref $_[0] ? ref shift() : shift();
    my ($file, $locator) = @_;
    croak "Invalid file name" unless defined $file && -f $file;

    my $info = {};
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(DateFormat => '%Y-%m-%d %H:%M:%S', CoordFormat => '%+.6f', , 
        QuickTimeUTC => 1, Exclude => ['ThumbnailImage']);
    #'%Y-%m-%d %H:%M:%S%z'

    $exifTool->ExtractInfo($file);

    foreach my $key (keys %FIELD_MAP) {
        my $map = $FIELD_MAP{$key};
        my $parser = $FIELD_PARSER{$key};
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
    $info->{file_ext} = substr($suffix, 1) if (defined $suffix) && ($suffix ne '');
    $info->{abs_dir} = $file_dir if defined $file_dir;
    $info->{file_dir} = $file_dir if defined $file_dir;
    $info->{file_name} = $file_name if defined $file_name;
    
    $info->{locator} = $locator if defined $locator && ref $locator eq 'Locator';

    return bless($info, $class);
}

sub base_dir
{
    my $self = shift;
    my $old = $self->{base_dir};
    if (@_) {
        $self->{base_dir} = shift;
        if (defined ($self->{base_dir}) && $self->{base_dir} ne ''
            && defined ($self->{abs_dir}) && $self->{abs_dir} ne '') {
            $self->{file_dir} = File::Spec->abs2rel( $self->{abs_dir}, $self->{base_dir} ) ;
        }
        else {
            $self->{file_dir} = $self->{abs_dir};
        }
    }
    return $old;
}

sub datetime
{
    shift->{date};
}

sub parse_template($$)
{
    my ($self, $str) = @_;
    return Template::parse { $self->get_value($_) } $str;
}

sub validate_template($;\@)
{
    return &Template::validate( sub { exists $VALUE_MAP{$_} }, @_);
}


sub get_value
{
    my ($self, $name) = @_;
    return unless ref($self) eq __PACKAGE__
        && exists $VALUE_MAP{$name};
#    return $value_map{$name} if ref($_value_map{$name}) eq 'SCALAR';
    return $VALUE_MAP{$name}->($self, $name) if ref($VALUE_MAP{$name}) eq 'CODE';
#    print "$name -> ", ref($value_map{$name}), "\n";
    return $VALUE_MAP{$name};
}


%FIELD_MAP = (
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

%FIELD_PARSER = (
    'date' => \&str2time,
    'latitude' => \&_parse_float,
    'longitude' => \&_parse_float,
    'title' => \&_parse_str,
    'album' => \&_parse_str,
    'artist' => \&_parse_str,
    'camera_make' => \&_parse_str,
    'camera_model' => \&_parse_str,
);


%VALUE_MAP = (
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
    'country' => \&_get_location,
    'state' => \&_get_location,
    'city' => \&_get_location,
#    'suburb' => \&_get_location,
);

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

sub _get_date_value
{
    my ($self, $fmt) = @_;
    return undef unless defined $fmt;
    return undef unless exists $self->{date};
    return strftime($fmt, localtime($self->{date}));
}

sub _get_info_value
{
    my ($self, $name) = @_;
    return undef unless defined $name;
    return undef unless exists $self->{$name};
    return $self->{$name};
}

sub _get_location
{
    my ($self, $name) = @_;
#    print STDERR __PACKAGE__, " _get_location($name)\n";
    return undef unless defined $name;
    unless (exists $self->{location}) {
        return unless defined $self->{latitude} && defined $self->{longitude};
        $self->{location} = $self->{locator}->locate($self->{latitude}, $self->{longitude}) if defined $self->{locator};
#        print STDERR __PACKAGE__, " find location:", Dumper($self->{location}),"\n";
    }
#    print STDERR __PACKAGE__, " location:", Dumper($self->{location}),"\n";
    return unless defined $self->{location};
    return $self->{location}->country if $name eq 'country';
    return $self->{location}->state if $name eq 'state';
    return $self->{location}->suburb  if $name eq 'suburb';
    return $self->{location}->city if $name eq 'city';
    undef;
}



1;
