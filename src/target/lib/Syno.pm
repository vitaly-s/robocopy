#!/usr/bin/perl
#
# @File syno.pm
# @Author vitalys
# @Created Aug 1, 2016 10:25:30 AM
#

package Syno;

1;

#see http://oinkzwurgl.org/?action=browse;oldid=ds106series;id=diskstation_ds106series
sub beep 
{
    `echo 2 > /dev/ttyS1`;
}

sub longbeep
{
    `echo 3 > /dev/ttyS1`;
}

sub copyled_off
{
    `echo B > /dev/ttyS1`;
}

sub copyled_on
{
    `echo @ > /dev/ttyS1`;
}

sub copyled_blink
{
    `echo A > /dev/ttyS1`;
}

#USAGE : synologset1 [sys | man | conn](copy netbkp)   [info | warn | err] eventID(%X) [substitution strings...]
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
sub notify 
{
    my ($msg, $title, $to) = @_;
    return unless defined $msg;
    $title = '' unless defined $title;
    $to = '@administrators' unless defined $to;
#	print "NOTIFY: $title - $msg\n";
    system('/usr/syno/bin/synodsmnotify', $to, $title, $msg);
}

sub share_path
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

sub share_list
{
    my @share_list;
    foreach my $name (`/usr/syno/sbin/synoshare --enum local | tail -n+3`) {
        $name =~ s/\n//g;
        my $comment = '';
        my $real_path = '';
        foreach (`/usr/syno/sbin/synoshare --get $name`) {
            if (/Comment.*\[(.*)\]/) {
                $comment = $1;
            }
            if (/Path.*\[(.*)\]/) {
                $real_path = $1;
            }
        }
        push @share_list, {'name' => $name, 'comment' => $comment, 'real_path' => $real_path};
    }
    return @share_list;
}

