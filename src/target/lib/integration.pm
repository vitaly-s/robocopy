#!/usr/bin/perl
#
# @File integration.pm
# @Author vitalys
# @Created Jul 21, 2016 3:17:23 PM
#

package integration; 

{
    use strict;
    use JSON::XS;
    use File::Copy;

    use Data::Dumper;
    
    use constant DEFAULT_FILE    => '/var/packages/robocopy/etc/integration.conf';

    use constant SYNO_USBCOPY_PATH => '/usr/syno/bin/synousbcopy';
    use constant SAVED_USBCOPY_PATH => '/usr/syno/bin/synousbcopy_bin';
    use constant MY_USBCOPY_PATH => '/var/packages/robocopy/target/bin/robocopy.pl';
#    use constant USBCOPY_PATH => '';
    use constant HOTPLUG_DEST_PATH => '/usr/syno/hotplug.d/default/99robocopy.hotplug';
    use constant HOTPLUG_SRC_PATH => '/var/packages/robocopy/target/bin/hotplug.sh';

    1;


    ### USBCopy ###
    sub is_run_after_usbcopy {
        return 0 unless -l SYNO_USBCOPY_PATH;
        return 0 unless -e SAVED_USBCOPY_PATH;
        return 0 unless readlink(SYNO_USBCOPY_PATH) == MY_USBCOPY_PATH;
        return 1;
    }

    sub set_run_after_usbcopy {
        return 0 if -e SAVED_USBCOPY_PATH;
        rename(SYNO_USBCOPY_PATH, SAVED_USBCOPY_PATH) || return 0;
        symlink(MY_USBCOPY_PATH, SYNO_USBCOPY_PATH) && return 1;
        #restore
        rename(SAVED_USBCOPY_PATH, SYNO_USBCOPY_PATH);
        return 0;
    }
    sub remove_run_after_usbcopy {
        return 0 unless -e SAVED_USBCOPY_PATH;
        return 0 unless -l SYNO_USBCOPY_PATH;
        return 0 unless readlink(SYNO_USBCOPY_PATH) == MY_USBCOPY_PATH;
        return rename(SAVED_USBCOPY_PATH, SYNO_USBCOPY_PATH);
    }

    ### On disk attach ###
    sub is_run_on_disk_attach {
        return 1 if -e HOTPLUG_DEST_PATH;
        return 0;
    }
    sub set_run_on_disk_attach {
        return copy(HOTPLUG_SRC_PATH, HOTPLUG_DEST_PATH);
    }
    sub remove_run_on_disk_attach {
        unlink(HOTPLUG_DEST_PATH) if -f HOTPLUG_DEST_PATH;
    }
    
    ### Save/Restore ###
    sub save_state
    {
        my ($remove, $file) = @_;
        $file = DEFAULT_FILE unless defined $file;
        $remove = 0 unless defined $remove;
        
        my $after_usbcopy = integration::is_run_after_usbcopy;
        my $on_attach_disk = integration::is_run_on_disk_attach;

        # write to file
        open my $fh, ">", $file || return 0;
        print $fh JSON::XS->new->utf8->encode({'after_usbcopy' => $after_usbcopy, 'on_attach_disk' => $on_attach_disk});
        close $fh;
        
        if ($remove) {
            $after_usbcopy && remove_run_after_usbcopy();
            $on_attach_disk && remove_run_on_disk_attach();
        }
        
        return 1;
    }

    sub restore_state
    {
        my ($remove, $file) = @_;
        $file = DEFAULT_FILE unless defined $file;
        $remove = 1 unless defined $remove;

        return 0 unless -f $file;
        
        my $cgf = do {
            local $/ = undef;
            open my $fh, "<", $file || die "could not open $file: $!";
            my $text = <$fh>;
            JSON::XS->new->utf8->decode($text);
        };
        set_run_after_usbcopy if defined $cgf->{after_usbcopy} && $cgf->{after_usbcopy};
        set_run_on_disk_attach if defined $cgf->{on_attach_disk} && $cgf->{on_attach_disk};
        
        $remove && unlink $file;

        return 1;
    }
}
