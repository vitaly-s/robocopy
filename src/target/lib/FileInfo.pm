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
use File::Compare;
use IO::File;
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
    
    $info->{locator} = $locator if defined $locator && ref $locator && $locator->isa('Locator');
    
    $info->{width} = $exifTool->GetValue('ImageWidth', 'ValueConv');
    $info->{height} = $exifTool->GetValue('ImageHeight', 'ValueConv');
    
    $info->{areas} = [];
    my @arType = $exifTool->GetValue('RegionType', 'ValueConv');
#    print STDERR "RegionType: (", scalar(@arType), "): [", join(', ', @arType),"]\n";
    my $regDimH = $exifTool->GetValue('RegionAppliedToDimensionsH')
        || $info->{height};
    my $regDimW = $exifTool->GetValue('RegionAppliedToDimensionsW') 
        || $info->{width};
    my $regDimUnit = $exifTool->GetValue('RegionAppliedToDimensionsUnit') 
        || 'pixel';

#    print STDERR "Image: $regDimW x $regDimH $regDimUnit\n";

    my @arX = $exifTool->GetValue('RegionAreaX', 'ValueConv');
    my @arY = $exifTool->GetValue('RegionAreaY', 'ValueConv');
    my @arH = $exifTool->GetValue('RegionAreaH', 'ValueConv');
    my @arW = $exifTool->GetValue('RegionAreaW', 'ValueConv');
    my @arName = $exifTool->GetValue('RegionName', 'ValueConv');
    while (defined ($_ = shift @arType)) {
        my $area = FileInfo::Area->new({
            'type' => _parse_str($_),
            'name' => _parse_str(shift(@arName)),
            'posX' => _parse_float(shift(@arX)),
            'posY' => _parse_float(shift(@arY)),
            'height' => _parse_float(shift(@arH)),
            'width' => shift(@arW)
            });
        push @{$info->{areas}}, $area;
    }


    return bless($info, $class);
}

sub new(;$)
{
    my $class = __PACKAGE__; #ref $_[0] ? ref shift() : shift();
    my $locator = shift;
    croak "Invalid locator" if defined $locator && ref $locator && !$locator->isa('Locator');
    my $info = {};
    $info->{locator} = $locator if defined $locator && ref $locator && $locator->isa('Locator');
    return bless($info, $class);
}

sub dumpExif($)
{
    my $file = shift;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(
#        DateFormat => '%Y-%m-%d %H:%M:%S', 
        StrictDate => 1,
        CoordFormat => '%+.6f',
        QuickTimeUTC => 1, 
#        Exclude => ['ThumbnailImage']
    );
    my $info = $exifTool->ImageInfo($file);
    my $result = '';
    foreach (sort keys %$info) {
        my $val = tagValue($$info{$_});
        my $tag = $exifTool->GetGroup($_, 0) . ':'. $_;

        $result .= sprintf("%-30s : %s\n", $tag, $val);
    }
    return $result;
}

sub tagValue($)
{
    my $val = shift;
    if (ref $val eq 'ARRAY') {
        $val = '[' . join(', ', @$val) . ']';
    } elsif (ref $val eq 'SCALAR') {
#        $val = '(Binary data)';
        if ($$val =~ /^Binary data/) {
            $val = "($$val)";
        } else {
            my $len = length($$val);
            $val = "(Binary data $len bytes)";
        }
    } else {
        utf8::decode($val) unless utf8::is_utf8($val);
    }
    
    return $val;
}

sub exifCompare($$)
{
    my ($file1, $file2) = @_;
    
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(
#        DateFormat => '%Y-%m-%d %H:%M:%S', 
        StrictDate => 1,
        CoordFormat => '%+.6f',
        QuickTimeUTC => 1, 
#        Exclude => ['ThumbnailImage']
    );
    my $info1 = $exifTool->ImageInfo($file1);
    my $info2 = $exifTool->ImageInfo($file2);
    
#    print STDERR $file1, "\n", $file2, "\n";
    foreach (sort keys %$info1) {
        my $tag = $exifTool->GetGroup($_, 0) . ':'. $_;
        my $val1 = tagValue($$info1{$_});
        my $val2 = (exists $$info2{$_} ? tagValue($$info2{$_}) : undef);
#        next if $val1 eq $val2;
        printf("%-24s | %-25s | %s\n", $tag, $val1, (defined $val2 ? $val2 : '<UNDEF>'));
    }
    foreach (sort keys %$info2) {
        next if exists $$info1{$_};
        my $tag = $exifTool->GetGroup($_, 0) . ':'. $_;
        my $val2 = tagValue($$info2{$_});
        printf("%-24s | %-25s | %s\n", $tag, '', $val2);
    }
}

sub update($$;$)
{
    my ($self, $file, $dest_file) = @_;

   return undef unless Image::ExifTool::CanWrite(defined $dest_file ? $dest_file : $file);

    my $exifTool = new Image::ExifTool;
    $exifTool->Options(
#        DateFormat => '%Y-%m-%d %H:%M:%S', 
        StrictDate => 1,
        CoordFormat => '%+.6f',
        QuickTimeUTC => 1, 
        Exclude => ['ThumbnailImage']
    );
    #'%Y-%m-%d %H:%M:%S%z'
    

    $exifTool->ExtractInfo($file);
    my @tags = $exifTool->GetFoundTags();
#     print STDERR "Found tags:\n", Dumper(\@tags), "\n";
    my @writableTags = $exifTool->GetWritableTags();
    # print STDERR "Writable tags:\n", Dumper(\@writableTags), "\n";
    # Update DATE
    if (exists $self->{date}) {
        my $dt;
        $dt = strftime('%Y-%m-%d %H:%M:%S', localtime($self->{date})) if defined $self->{date};
        _update_tags($exifTool, $dt, @{$FIELD_MAP{date}});
    }
    # Update TITLE
    if (exists $self->{title}) {
        my $title = $self->{title};
        _update_tags($exifTool, $title, @{$FIELD_MAP{title}});
    }
    # Update LOCATION
    if (exists $self->{latitude} && exists $self->{longitude}) {
        _update_tags($exifTool, $self->{latitude}, @{$FIELD_MAP{latitude}});
        _update_tags($exifTool, 
            (defined $self->{latitude} 
                ? ($self->{latitude} < 0 ? 'S' : 'N')
                : undef),
            'EXIF:GPSLatitudeRef');
        _update_tags($exifTool, $self->{longitude}, @{$FIELD_MAP{longitude}});
        _update_tags($exifTool, 
            (defined $self->{longitude}
                ? ($self->{longitude} < 0 ? 'W' : 'E')
                : undef),
            'EXIF:GPSLongitudeRef');
    }
    # Update AREAS
    if ( exists $self->{areas}) {
        if (scalar(@{$self->{areas}}) > 0) {
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsH' => $exifTool->GetValue('ImageHeight'), Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsUnit' => 'pixel', Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsW' => $exifTool->GetValue('ImageWidth'), Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaH' => [ map { $_->height } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaW' => [ map { $_->width } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaX' => [ map { $_->posX } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaY' => [ map { $_->posY } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionName' => [ map { $_->name } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionRotation' => [ map { 0 } @{$self->areas} ], Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionType' => [ map { $_->type } @{$self->areas} ], Protected => 1);
#RegionAreaUnit                  : normalized
        }
        else {
            # Remove areas properties
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsH' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsUnit' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAppliedToDimensionsW' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaH' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaW' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaX' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionAreaY' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionName' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionRotation' => undef, Protected => 1);
            $exifTool->SetNewValue('XMP-mwg-rs:RegionType' => undef, Protected => 1);
        }
    }

#    $exifTool->SetNewValue('xmp:all');
#    printf STDERR "\tRemove XMP properties\n";
    if (grep( { $_ eq 'XMPToolkit' } @tags ) == 0) {
#        printf STDERR "\t\tRemove XMPToolkit\n";
        $exifTool->SetNewValue('XMP-x:XMPToolkit' => undef, Protected => 1);
    }
    $exifTool->SetNewValue('XMP:CreationDate' => undef, Protected => 1);
#    printf STDERR "\tWrite : $file\n";
#    unlink($dest_file) if -f $dest_file;

    my $result = $exifTool->WriteInfo($file, $dest_file);
#    print STDERR __PACKAGE__, " WriteInfo: ".(defined $result ? $result : '<UNDEF>'). "\n";
    unless ($result) {
#        my $errorMessage = $exifTool->{'Error'};
#        my $warningMessage = $exifTool->{'Warning'};
#        print STDERR __PACKAGE__, " Update [" . basename($file) . "] error: \n";
#        print STDERR "\t $errorMessage\n" if defined $errorMessage;
#        print STDERR "\t $warningMessage\n" if defined $warningMessage;
        
    }
    if (defined $self->{date}) {
#        printf STDERR "\tUpdate file modify date\n";
        $exifTool->SetFileModifyDate(defined $dest_file ? $dest_file : $file);
    }   
#    exifCompare($file, $dest_file);
    return $result;
}

sub _update_tags($$@)
{
    my ($exifTool, $value, @tags) = @_;

    if (defined $value) {
        my $updated = 0;
        # Try update exists tags
        foreach my $tag (@tags) {
#            printf STDERR "\tTry update '$tag' = '$value'\n";
            my $old_value = $exifTool->GetValue($tag);
#            printf STDERR "\t\t$tag == '$old_value'\n";
            if (defined $old_value) {
                #my ($x, undef) = 
                $exifTool->SetNewValue($tag => $value, EditOnly => 1, Protected => 1);
                ++$updated;
            }
            
        }
        if ($updated == 0) {
            my $tag = $tags[0];
#            printf STDERR "\tTry add '$tag' = '$value'\n";
            $exifTool->SetNewValue($tag => $value, Protected => 1);
        }
    }
    else {
        foreach my $tag (@tags) {
            my $old_value = $exifTool->GetValue($tag);
#            printf STDERR "\t\t$tag == '$old_value'\n";
            if (defined $old_value) {
#                printf STDERR "\tTry delete '$tag'\n";
                #(undef,undef)=
                $exifTool->SetNewValue($tag => undef, Protected => 1);
            }
        }
    }
}

sub cmp_files($$)
{
    my ($file1, $file2) = @_;

    printf STDERR "Try compare '$file1' and '$file2'\n";

    my @st1 = stat($file1);
    if (@st1) {
        my @st2 = stat($file2);
        if (@st2 && $st1[0] == $st2[0] && $st1[1] == $st2[1]) {
            printf STDERR "'$file1' and '$file2' are identical\n";
            return 0;
        }
    }
    if (Image::ExifTool::CanWrite($file1) 
        && Image::ExifTool::CanWrite($file2)) {

        printf STDERR "\tTry create temporary files\n";
        my $fh1 = IO::File->new_tmpfile;
        my $fh2 = IO::File->new_tmpfile;
        
        if (defined $fh1 && defined $fh2) {
            my $exifTool = new Image::ExifTool;

            printf STDERR "\tTry clear EXIF data '$file1'\n";
            $exifTool->ExtractInfo($file1);
            $exifTool->SetNewValue('*');
            $fh1->autoflush(1);
            $exifTool->WriteInfo($file1, $fh1);
            seek($fh1, 0, 0);
            
            printf STDERR "\tTry clear EXIF data '$file2'\n";
            $exifTool->ExtractInfo($file2);
            $exifTool->SetNewValue('*');
            $fh2->autoflush(1);
            $exifTool->WriteInfo($file2, $fh2);
            seek($fh2, 0, 0);
            
#            exifCompare($fh1, $fh2);
#            seek($fh1, 0, 0);
#            seek($fh2, 0, 0);

            return compare($fh1, $fh2);
        }
        else {
            printf STDERR "Cannot create temporary files.\n";
            return 2;
        }
    }
    printf STDERR "\tUse full compare '$file1' and '$file2'\n";
    return compare($file1, $file2); 
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
    my $self = shift;
    my $old_value = $self->{date};
    if (@_) {
        $self->{date} = shift;
    }
    $old_value;
}

sub title
{
    my $self = shift;
    my $old_value = $self->{title};
    if (@_) {
        $self->{title} = shift;
    }
    $old_value;
}

sub areas
{
    my $self = shift;
    my $old_value = $self->{areas};
    if (@_) {
        my @args = (scalar @_ == 1 
            ? (ref $_[0] eq 'ARRAY' 
                ? @{$_[0]}
                : @_
            )
            : @_
        );
        foreach (@args) {
            croak 'All elements must be a FileInfo::Area ref data' 
                unless ref $_ && $_->isa('FileInfo::Area');
        }
        $self->{areas} = \@args;
    }
    $old_value;
}

sub width
{
    shift->{width};
}

sub height
{
    shift->{height};
}

sub location($)
{
    shift->{location};
#    my $self = shift;
#    my $old_value = $self->{location};
#    if (@_) {
#        croak 'First parameter to location() must be a Geo::Address ref data' unless ref $_[0]
#                                                                && $_[0]->isa('Geo::Address');
#
#        $self->{location} = shift;
#        if (@_) {
#            my $point = scalar @_ == 1
#                ? (ref $_[0] eq 'HASH'
#                    ? {%{$_[0];}}
#                    : croak('Second parameter to location() must be a HASH')
#                )
#                : (@_ % 2 
#                    ? croak("Second parameter to location() must be a hash reference or a" 
#                        . " key/value list. You passed an odd number of arguments\n") 
#                    : {@_}
#                );
#            $self->{latitude} = $point->{latitude};
#            $self->{longitude} = $point->{longitude};
#        }
#    }
#    $old_value;
}

sub get_location
{
    my $self = shift;
    unless (exists $self->{location}) {
        if (defined $self->{locator} 
            && defined $self->{latitude} 
            && defined $self->{longitude}) {
            $self->{location} = $self->{locator}->locate($self->{latitude}, $self->{longitude});
        }
    }
    $self->{location};
}


sub search_location($$)
{
    my ($self, $query) = @_;
    
    if (defined $query && $query ne '') {
        return undef unless defined $self->{locator};
        my ($address, $point) = $self->{locator}->search($query);
        return 0 unless defined $address;
        $self->{location} = $address;
        $self->{latitude} = $point->{latitude};
        $self->{longitude} = $point->{longitude};
    }
    else {
        $self->{location} = undef;
        $self->{latitude} = undef;
        $self->{longitude} = undef;
    }
    1;
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
    'title' => ['Title', 'DisplayName', 'Title2'],
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
    'country' => \&_get_location_value,
    'state' => \&_get_location_value,
#    'county' => \&_get_location_value,
    'city' => \&_get_location_value,
#    'suburb' => \&_get_location_value,
#    'road' => \&_get_location_value,
#    'house' => \&_get_location_value,
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

sub _get_location_value
{
    my ($self, $name) = @_;
#    print STDERR __PACKAGE__, " _get_location($name)\n";
    return undef unless defined $name;
    my $location = $self->get_location();
#    print STDERR __PACKAGE__, " location:", Dumper($self->{location}),"\n";
    return unless defined $location;
    return $location->country if $name eq 'country';
    return $location->state if $name eq 'state';
    return $location->county if $name eq 'county';
    return $location->city if $name eq 'city';
#    return $location->suburb  if $name eq 'suburb';
#    return $location->road  if $name eq 'road';
#    return $location->house  if $name eq 'house';
    undef;
}

{
    package FileInfo::Area;
    
    sub new(;$)
    {
        my $class = ref $_[0] ? ref shift() : shift();
        my $args = scalar @_ == 1 
            ? (ref $_[0] eq 'HASH' 
                ? {%{$_[0];}}
                : croak('Single parameters to '.$class.':new() must be a HASH ref data => ' . $_[0] . "\n")
            )
            : (@_ % 2 
                ? croak("The new() method for $class expects a hash reference or a" 
                    . " key/value list. You passed an odd number of arguments\n") 
                : {@_}
            );

        my $new = bless({}, $class);
        foreach my $key (qw(posX posY height width name type)) {
            next unless defined $args->{$key};
            $new->$key($args->{$key});
        }
        return $new;
    }
    
    sub posX
    {
        my $self = shift;
        my $old_value = $self->{posX};
        if (@_) {
            $self->{posX} = shift;
        }
        $old_value;
    }
    
    sub posY
    {
        my $self = shift;
        my $old_value = $self->{posY};
        if (@_) {
            $self->{posY} = shift;
        }
        $old_value;
    }
    sub height
    {
        my $self = shift;
        my $old_value = $self->{height};
        if (@_) {
            $self->{height} = shift;
        }
        $old_value;
    }
    sub width
    {
        my $self = shift;
        my $old_value = $self->{width};
        if (@_) {
            $self->{width} = shift;
        }
        $old_value;
    }
    sub name
    {
        my $self = shift;
        my $old_value = $self->{name};
        if (@_) {
            $self->{name} = shift;
        }
        $old_value;
    }
    sub type
    {
        my $self = shift;
        my $old_value = $self->{type};
        if (@_) {
            $self->{type} = shift;
        }
        $old_value;
    }

}

1;
