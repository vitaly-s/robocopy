#!/usr/bin/perl
#
# @File syno.pm
# @Author vitalys
# @Created Aug 1, 2016 10:25:30 AM
#

package Syno;

use strict;
use utf8;
use Encode;

1;

#see https://oinkzwurgl.org/attic/diskstation/diskstation_ds106series/
sub _led_control($)
{
    my $cmd = shift;
    open my $fh, ">/dev/ttyS1" or return undef;
    print $fh $cmd;
    close $fh;
    1;
}

sub beep 
{
    # echo 2 | tee -p /dev/ttys1 &>/dev/null
    #`echo 2 > /dev/ttyS1`;
    _led_control '2';
}

sub longbeep
{
#    `echo 3 > /dev/ttyS1`;
    _led_control '3';
}

sub copyled_off
{
#    `echo B > /dev/ttyS1`;
    _led_control 'B';
}

sub copyled_on
{
#    `echo @ > /dev/ttyS1`;
    _led_control '@';
}

sub copyled_blink
{
#    `echo A > /dev/ttyS1`;
    _led_control 'A';
}

#USAGE : synologset1 [sys | man | conn](copy netbkp)   [info | warn | err] eventID(%X) [substitution strings...]
# eventIDs /usr/syno/synosdk/texts/enu/events
sub log
{
    my ($msg, $type, $log) = @_;
    return unless defined $msg;
    $msg =~ s/'/''/g;
    $type = 'info' unless defined $type;
    $log = 'sys' unless defined $log;
#    print uc($log), ':', uc($type), " - '$msg'.\n";
    system('/usr/syno/bin/synologset1', $log, $type, '0x11800000', 'RoboCopy: ' . $msg);
}

#http://forum.synology.com/enu/viewtopic.php?f=27&t=55627
# Old /usr/syno/bin/synodsmnotify -c SYNO.SDS.RoboCopy.Instance @administrators app:app_name error:bad_field XXX
# DSM 7 /usr/syno/bin/synodsmnotify -c SYNO.SDS.RoboCopy.Instance -t robocopy @administrators robocopy:app:app_name robocopy:error:bad_field XXX

sub notify 
{
    my ($msg, $title, $to) = @_;
    return unless defined $msg;
    $title = '' unless defined $title;
    $to = '@administrators' unless defined $to;
#	print "NOTIFY: $title - $msg\n";
    system('/usr/syno/bin/synodsmnotify', $to, $title, $msg);
}

sub _parse_smb_conf
{
    my($file) = @_;
    return undef if (!defined $file || ($file eq '') );
    return undef unless ( -f $file );
    
    my $contents = do {
        local $/ = undef;
        open my $fh, "<:utf8", $file or return undef;
        <$fh>;
    };

    my @share_list = ();
    my $share;
    foreach ( split /(?:\015{1,2}\012|\015|\012)/, $contents) {
        # Skip comments and empty lines.
        next if /^\s*(?:\#|\;|$)/;

        # Remove inline comments.
        s/\s\#\s.+$//g;

        # Handle section headers.
        if ( /^\s*\[\s*(.+?)\s*\]\s*$/ )
        {
            my $name = $1;
            utf8::decode($name) unless utf8::is_utf8($name);
            $share = {'name' => $name};
            next;
        }
        if ( /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ )
        {
            my ($name, $value) = ($1, $2);
            utf8::decode($value) unless utf8::is_utf8($value);
            if ($name eq "path") {
                $share->{'real_path'} = $value;
                push @share_list, $share;
            }
            elsif ($name eq "comment") {
                $value =~ s/"(.*)"$/$1/g;
                $share->{'comment'} = $value;
            }
            next;
        }

    }
    return \@share_list;
}

sub _run_synoshare
{
    my @share_list = ();
    foreach my $name (`/usr/syno/sbin/synoshare --enum local | tail -n+3`) {
        $name =~ s/\n//g;
        $name = decode("UTF-8", $name);
        my $comment = '';
        my $real_path = '';
        foreach (`/usr/syno/sbin/synoshare --get "$name"`) {
            if (/Comment.*\[(.*)\]/) {
                $comment = decode("UTF-8", $1);
            }
            if (/Path.*\[(.*)\]/) {
                $real_path = decode("UTF-8", $1);
            }
        }
        push @share_list, {'name' => $name, 'comment' => $comment, 'real_path' => $real_path};
    }
    return \@share_list;
}


sub share_path
{
    my $share = shift;
    if (defined $share) {
#        my @out = `/usr/syno/sbin/synoshare --get "$share"`; 
#        foreach  (@out) {
#            if (/Path.*\[(.*)\]/) {
#                return decode("UTF-8", $1);
#            }
#        }
        my @list = share_list();
        foreach my $item (@list) {
            if ($share eq $item->{'name'}) {
                return $item->{'real_path'};
            }
        }
    }
    return undef;
}


sub share_list
{
    my $share_list = _parse_smb_conf("/etc/samba/smb.share.conf") 
        || _parse_smb_conf("/usr/syno/etc/smb.conf")
        || _run_synoshare;
    return (wantarray ? @$share_list : $share_list);
}

sub serial_number
{
    `cat /proc/sys/kernel/syno_serial`;
}
