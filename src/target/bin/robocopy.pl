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
#use JSON::XS;
use File::Find;
use File::Basename;
use File::Spec;
use File::Glob;
use File::Path;
use File::Compare;
use File::Copy;
use Data::Dumper;
use POSIX qw(strftime);
use Time::Local;

# add our 'lib' directory to the include list BEFORE 'use Image::ExifTool'
BEGIN {
    # get exe directory
    my $exeDir = ($0 =~ /(.*)[\\\/]/) ? $1 : '.';
	print "$exeDir \n";
    
    # add lib directory at start of include path
    unshift @INC, "$exeDir/../lib";
    unshift @INC, "/var/packages/robocopy/target/lib";

    require "config.pl";
#    # disable config file if specified
#    if (@ARGV and lc($ARGV[0]) eq '-config') {
#        shift;
#        $Image::ExifTool::configFile = shift;
#    }
} 
#for my $lib_path (@INC)
#{
#	print "$lib_path\n";
#}
use Image::ExifTool qw(:Public);
use constant ORIGINAL_SYNOUSBCOPY => '/usr/syno/bin/synousbcopy_bin';

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
		my $copy_dir = syno_share_path(`get_key_value /etc/synoinfo.conf $name`);
		syno_log("Can not get \"$name\" path."), delete $copy_hash{$name}, next unless defined $copy_dir;
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
			my $share_path = syno_share_path($share_name);
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

syno_beep();

# Read config
my $cfg = read_cfg(DEFAULT_CONFIG, 'priority');

# Preprocess config
my $rule_count = 0;
foreach my $rule (@$cfg) {
	my $dest_path = syno_share_path($rule->{'dest_folder'});
	syno_log("Invalid destination share name: \"$rule->{dest_folder}\"."), next unless defined $dest_path;
	$dest_path .= '/' . ((defined $rule->{'dest_dir'} && $rule->{'dest_dir'} ne '') ? $rule->{'dest_dir'} : '%%d');
	$dest_path .= '/' . ((defined $rule->{'dest_file'} && $rule->{'dest_file'} ne '') ? $rule->{'dest_file'} : '%%f');
	$dest_path .= '.' . ((defined $rule->{'dest_ext'} && $rule->{'dest_ext'} ne '') ? $rule->{'dest_ext'} : '%%e');
	while ($dest_path =~ /\/\//) { $dest_path =~ s/\/\//\//g; }
	$rule->{dest_path} = $dest_path;
	
	my $src_ext = $rule->{src_ext};
	$src_ext = '*' if !defined($src_ext) || $src_ext eq '';
	$rule->{src_mask} = $src_ext eq '*' ? '(\..*?|)$' : "\.$src_ext\$";
	++$rule_count;
}

# Main cycle
my $progress_completed = 0.0;
my $progress_total = @dirs * $rule_count;
#print 'Progress total: ', $progress_total, "\n";
foreach my $dir (@dirs) {
	syno_log("Start process \"$dir\"");
#	print "Process \"$dir\"\n";
	foreach my $rule (@$cfg) {
		next unless defined($rule->{dest_path}) && defined($rule->{src_mask});
		print "\tProcess \"$rule->{description}\" [$rule->{src_dir}/$rule->{src_mask}]\n\t\t$rule->{dest_path}\n" if $verbose;
		my $src_remove = $rule->{src_remove};
		$src_remove = 0 unless defined $src_remove;

#		print 'Progress :', 100 * $progress_completed / $progress_total, "%\n";
		$progress_completed++;
		# Build file list
		my @files;
#		my $total_size = 0;
		my $src_dir = $rule->{src_dir};
		$src_dir = '' unless defined $src_dir;
		my $src_path = $dir . "/$src_dir/";
		fix_path($src_path);
#		while ($src_path =~ /\/\//) { $src_path =~ s/\/\//\//g; }
		
		next unless -d $src_path;
		print "\t$src_path\n" if $verbose;
		find sub {
			if ( -f && /$rule->{src_mask}/i) { 
				push @files, $File::Find::name;
#				$total_size += -s;
			} 
		}, $src_path;

		# Process files
		foreach my $file (@files) {
			# Make output file name
			my $file_time = file_original_time($file);
			my $dest_file = strftime($rule->{dest_path}, localtime($file_time));
			my @parts = ($file =~ /^(.*?)([^\/]*?)(\.[^.\/]*)?$/);
			$parts[2] = $parts[2] ? substr($parts[2], 1) : '';
			$parts[0] = substr($parts[0], length($src_path));
			foreach my $key ('d','f','e') {
				my $val = shift @parts;
				while ($dest_file =~ /%$key/g) {
					$dest_file =~ s/%$key/$val/;
				}
			}
			fix_path($dest_file);

			print "\t\t$file -> $dest_file\n" if $verbose;
			# Create destination dir
			mkpath(dirname($dest_file), 0, 0755);
			
			if (-d $dest_file) {
				syno_log("Cannot overwrite directory \"$dest_file\"", 'warn');
			}
			elsif (-f $dest_file) {
				if (compare($file, $dest_file) == 1) {
					syno_log("Cannot overwrite file \"$dest_file\", because it not identical to \"$file\"", 'warn');
				}
				elsif ($src_remove) {
					unlink($file) || syno_log("Cannot delete file \"$file\"", 'warn');
				}
			}
			else {
				$writed_file = $dest_file;
				if ($src_remove) {
					rename($file, $dest_file) || syno_log("Cannot move file \"$file\" to \"$dest_file\"", 'warn');
				}
				else {
					copy($file, $dest_file) || syno_log("Cannot copy file \"$file\" to \"$dest_file\"", 'warn');
				}
				utime($file_time, $file_time, $dest_file);
				undef $writed_file;
			}
		};
	}
	syno_log("Finished process \"$dir\"");
}
if ($#dirs > 0) {
	syno_notify('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy');
}
else {
	syno_notify('Finished process directory "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy');
}


#############################
#see http://oinkzwurgl.org/?action=browse;oldid=ds106series;id=diskstation_ds106series
sub syno_beep 
{
	`echo 2 > /dev/ttyS1`;
}

sub syno_longbeep
{
	`echo 3 > /dev/ttyS1`;
}

sub syno_copyled_off
{
	`echo B > /dev/ttyS1`;
}

sub syno_copyled_on
{
	`echo @ > /dev/ttyS1`;
}

sub syno_copyled_blink
{
	`echo A > /dev/ttyS1`;
}

#USAGE : synologset1 [sys | man | conn](copy netbkp)   [info | warn | err] eventID(%X) [substitution strings...]
sub syno_log
{
	my ($msg, $type, $log) = @_;
	return unless defined $msg;
	$msg =~ s/'/''/g;
	$type = 'info' unless defined $type;
	$log = 'sys' unless defined $log;
#	print uc($log), ':', uc($type), " - '$msg'.\n";
	system('/usr/syno/bin/synologset1', $log, $type, '0x11800000', 'RoboCopy: ' . $msg);
#	exec('/usr/syno/bin/synologset1 sys ' . $type . ' 0x11800000 ' . escapeshellarg('RoboCopy: ' . $str));
#	exec('/usr/syno/bin/synologset1 copy ' . $type . ' 0x11800000 ' . escapeshellarg('RoboCopy: ' . $str));
}

#http://forum.synology.com/enu/viewtopic.php?f=27&t=55627
sub syno_notify 
{
	my ($msg, $title, $to) = @_;
	return unless defined $msg;
	$title = '' unless defined $title;
	$to = '@administrators' unless defined $to;
#	print "NOTIFY: $title - $msg\n";
	system('/usr/syno/bin/synodsmnotify', $to, $title, $msg);
}

sub syno_share_path
{
	my $share = shift;
	if (defined $share) {
		my @out = `/usr/syno/sbin/synoshare --get $share`; 
		foreach  (@out) {
			if (/Path.*\[(.*)\]/) {
				return $1;
			}
		}
	}
	return undef;
}

#############################
sub fix_path
{
	$_[0] =~ tr/\\/\//; 
	while ($_[0] =~ /\/\//) { $_[0] =~ s/\/\//\//g; }
	$_[0] =~ s/\.+$//;
}

sub file_original_time
{
	my $file = shift;
	return undef unless defined $file;
	my $info = ImageInfo($file, 'DateTimeOriginal', 'DateTimeDigitized');#, 'DateTime');
	if (exists $info->{'DateTimeOriginal'}) {
		my @date = reverse(split(/[: ]/, $info->{'DateTimeOriginal'}));
		--$date[4];
		return timelocal(@date);
	}
	if (exists $info->{'DateTimeDigitized'}) {
		my @date = reverse(split(/[: ]/, $info->{'DateTimeDigitized'}));
		--$date[4];
		return timelocal(@date);
	}
	#print Dumper($info), "\n";
	
	return (stat($file))[9];
}

sub out
{
}

sub cleanup
{
  unlink($writed_file) if defined $writed_file && -f $writed_file;
}

sub handle_user_abort
{
	syno_log("Was interrupted by user", 'warn');
	cleanup();
	exit 255;
}

sub handle_system_abort
{
	syno_log("Was terminated", 'warn');
	cleanup();
	exit 255;
}