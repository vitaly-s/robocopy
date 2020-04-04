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
use FileInfo;


BEGIN {
    # get exe directory
    my $scriptDir = dirname($0);

    unshift @INC, "$scriptDir";
} 

use Image::ExifTool qw(:Public);    
use Syno;
use Locator;

my $writed_file;

use constant EXCLUDE_NAMES => (
    '@tmp',
    '@eadir',
#    '.SynologyWorkingDirectory',
    '#recycle',
#    'desktop.ini',
#    '.DS_STORE',
#    'Icon\r',
    'thumbs.db',
#    '$Recycle.Bin',
    '@sharebin',
#    'System Volume Information',
#    'Program Files',
#    'Program Files (x86)',
#    'ProgramData',
    '#snapshot',
);


sub new {
    my($class, $rule, $locator) = @_;
    
#        print 'ref rule: ' . ref($rule) . "\n";
    
    $rule = {} unless ref($rule) eq 'HASH' || ref($rule) eq 'rule';

    my $self = { };

    foreach my $key (keys %{$rule}) {
        $self->{$key} = $rule->{$key};
    }
    $self->{locator} = $locator if defined $locator && ref($locator) eq 'Locator';
    
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

sub validate_template($;\@)
{
    &FileInfo::validate_template(@_);
}

sub prepare($$;\$) {
    my $tmp_error;
    my($self, $dir, $error) = @_;
    
#        print 'ref error: ' . ref($error) . "\n";
    $error = \$tmp_error unless ref($error) eq 'SCALAR';

    my $src_ext = $self->{src_ext};
    $src_ext = '' unless defined($src_ext);
    if ($src_ext eq '') {
        $self->{src_mask} = '^(\.|)$';
    }
    elsif ($src_ext =~ /^\*+$/) {
        $self->{src_mask} = '^(\..*?|)$';
    }
    else {
        $src_ext =~ s/\?/./;
        $src_ext =~ s/\*/.*?/;
        $self->{src_mask} = "^\.$src_ext\$";
    }

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
#    my $src_dir = $self->{src_dir};
#    $src_path = catdir($src_path, $src_dir) if defined $src_dir;
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
                my $file_name = $_;
                utf8::decode($file_name) unless utf8::is_utf8($file_name);
                # Skip exclude names
                foreach my $exclude (EXCLUDE_NAMES) {
                    if ($file_name =~ /$exclude/i){
                        $File::Find::prune = 1;
                        return;
                    }
                }
                if (-d "$file_name") {
                    return;
                }
                my $file_dir = $File::Find::dir;
                utf8::decode($file_dir) unless utf8::is_utf8($file_dir);
                my $file_path = catfile($file_dir, $file_name);
#                    print STDERR "0: '$_'" . (utf8::is_utf8($_) ? "[UTF8]" : "[bytes]") . "\n";
                my $file_ext = (fileparse($file_name, qr/\.[^.]*/))[2];
                if ( -f "$file_name" && $file_ext =~ /$self->{src_mask}/i) { 
#                    print STDERR "1: '$file_path" . (utf8::is_utf8($file_path) ? "[UTF8]" : "[bytes]") . "\n";
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
    my $info = FileInfo::load($file, $self->{locator});
    $$ref_file_time = $info->datetime if ref($ref_file_time) eq 'SCALAR';
    $info->base_dir($self->{src_path}) if defined $self->{src_path};
    my $file_time = $info->datetime;
    my $dest_file = $info->parse_template($self->{dest_path});
    utf8::decode($dest_file) unless utf8::is_utf8($dest_file);
    $dest_file = canonpath($dest_file);
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
            unless (move($file, $dest_file)) {
                $$error = "Cannot move file \"$file\" to \"$dest_file\": $!";
                return 0;
            }
        }
        else {
            unless (copy($file, $dest_file)) {
                $$error = "Cannot copy file \"$file\" to \"$dest_file\": $!";
                return 0;
            }
        }
        # update file owner
        chown $self->{user_uid}, $self->{user_gid}, ($dest_file) if defined($self->{user_uid}) && defined ($self->{user_gid});
        # update file time
        utime($file_time, $file_time, $dest_file);
        undef $writed_file;
    }
    return 1;
}

sub crear_dir(@)
{
    foreach my $top_dir (@_) {
        print STDERR "Try clear '$top_dir'\n";
    }
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
