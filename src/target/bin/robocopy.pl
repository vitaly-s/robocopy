#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell
#------------------------------------------------------------------------------
# File:         robocopy
#
# Description:  
#
# Revisions:    
#
# References:   
#------------------------------------------------------------------------------
use strict;
use File::Basename;

# add our 'lib' directory to the include list BEFORE 'use Image::ExifTool'
#BEGIN {
#    # get exe directory
##    my $scriptDir = ($0 =~ /(.*)[\\\/]/) ? $1 : '.';
#    my $scriptDir = dirname($0);
#    
#    # add lib directory at start of include path
#    unshift @INC, "$scriptDir/../lib";
#    unshift @INC, "/var/packages/robocopy/target/lib";
#} 
use FindBin qw($Bin);
use lib "$Bin/../lib";

use rule;
use rule_processor;
use Syno;
use integration;
use Geo::Coder;
use Locator;
use Settings;


use Image::ExifTool qw(:Public);

use constant ORIGINAL_SYNOUSBCOPY => integration::SAVED_USBCOPY_PATH;

my $verbose = 0;
my @dirs;
my $writed_file;

$SIG{INT} = \&handle_user_abort;
$SIG{KILL} = \&handle_system_abort;
$SIG{TERM} = \&handle_system_abort;


if (basename($0) eq 'synousbcopy') {
    unless (-x ORIGINAL_SYNOUSBCOPY) {
        print "Original version of SYNOUSBCOPY not exists!\n";
        exit 255;
    }
    my %copy_hash = ('usbcopyfolder'=>'USBCopy*', 'sdcopyfolder'=>'SDCopy*');
    my %copy_dirs;
    foreach my $name (keys(%copy_hash)) {
        my $copy_dir = Syno::share_path(`get_key_value /etc/synoinfo.conf $name`);
        Syno::log("Can not get \"$name\" path."), delete $copy_hash{$name}, next unless defined $copy_dir;
        $copy_hash{$name} = $copy_dir . '/' . $copy_hash{$name};
        foreach (glob($copy_hash{$name})) {
            $copy_dirs{$_} = 0;
        }
    }

    #RUN synousbcopy
    system(ORIGINAL_SYNOUSBCOPY, @ARGV);


    foreach my $name (keys(%copy_hash)) {
        foreach (glob($copy_hash{$name})) {
            $copy_dirs{$_}++;
        }
    }
    foreach (keys %copy_dirs) {
        push @dirs, $_ if ($copy_dirs{$_} == 0);
    }
    exit if ($#dirs < 0);
}
else {
    # parse args
    foreach my $arg (@ARGV) {
        $arg =~ s/\/+$//;
        if ($arg =~ /^@(\w+)/) {
            # replace share name
            my $share_name = $1;
            my $share_path = Syno::share_path($share_name);
            next unless defined $share_path;
            $arg =~ s/[@]$share_name/$share_path/;
        }
        if (-d $arg) {
#			print "\t$arg\n";
            push @dirs, $arg;
        }
    #	elsif ($arg =~ /[*?]/)
    }
    if ($#dirs < 0) {
        print "Usage: ", basename($0) . " src_dir1 [src_dir1...]\n\n";
        exit(1);
    }
}

Syno::beep();

# Read config
my $cfg = rule::load_list(undef, 'priority');

# Create locator
#    my $coder = create_geocoder(); #agent => "XXX");
my $locator = Locator->new();
eval {
    my $setting = Settings::load;
    $locator->threshold($setting->locator_threshold);
    $locator->language($setting->locator_language);
};

# Main cycle
my $error;
foreach my $dir (@dirs) {
    Syno::log("Start process \"$dir\"");
#    print "Process \"$dir\"\n";
    foreach my $rule (@$cfg) {
#        print "\tProcess \"$rule->{description}\" [$rule->{src_dir}/$rule->{src_mask}]\n\t\t$rule->{dest_path}\n" if $verbose;
        my $processor = new rule_processor($rule, $locator);
        if ($processor->prepare($dir, \$error)) {
            print "\t" . $processor->src_dir() . "\n" if $verbose;
            my $files = $processor->find_files();
            foreach my $file (@$files) {
                unless ($processor->process_file($file, \$error)) {
                    Syno::log($error, 'warn');
                }
            }
        }
        else {
            Syno::log($error, 'warn');
        }
    }
    Syno::log("Finished process \"$dir\"");
}


if ($#dirs > 0) {
    Syno::notify('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy');
}
else {
    Syno::notify('Finished process directory "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy');
}


#############################

sub handle_user_abort
{
    Syno::log("Was interrupted by user", 'warn');
    rule_processor::cleanup();
    exit 255;
}

sub handle_system_abort
{
    Syno::log("Was terminated", 'warn');
    rule_processor::cleanup();
    exit 255;
}
