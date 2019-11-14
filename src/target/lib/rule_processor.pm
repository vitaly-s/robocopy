#!/usr/bin/perl
#
# @File rule_processor.pm
# @Author vitalys
# @Created Sep 6, 2016 8:52:33 AM
#

package rule_processor;
{
    use strict;
    use File::Basename;
    use File::Find;
    use File::Spec::Functions;
    use File::Path;
    use File::Compare;
    use File::Copy;
    use POSIX qw(strftime);
    use Time::Local;


    BEGIN {
        # get exe directory
        my $scriptDir = dirname($0);

        unshift @INC, "$scriptDir";
    } 

    use Image::ExifTool qw(:Public);    
    use Syno;

    my $writed_file;
    
    1;
    
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
        return '%%d' unless defined $self->{dest_dir} && $self->{dest_dir} ne '';
        return $self->{dest_dir};
    }

    sub dest_file {
        my $self = shift;
        return '%%f' unless defined $self->{dest_file} && $self->{dest_file} ne '';
        return $self->{dest_file};
    }

    sub dest_ext {
        my $self = shift;
        return '%%e' unless defined $self->{dest_ext} && $self->{dest_ext} ne '';
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
        $self->{dest_path} = catfile($syno_folder, $self->dest_dir(), $self->dest_file() . '.' . $self->dest_ext());

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
        my $files = [];
        my ($self, $total_size) = @_;
        $$total_size = 0 if ref($total_size) eq 'SCALAR';

        
        if ($self->is_prepared()) {
            my $src_path = $self->{src_path};

            if ( -d $src_path) {
#                   print "\t$src_path\n" if $verbose;
                find sub {
                    if ( -f && /$self->{src_mask}/i) { 
                        push @$files, $File::Find::name;
                        $$total_size += -s $File::Find::name if ref($total_size) eq 'SCALAR';
                    } 
                }, $src_path;
            }
        }
        return $files
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
        
        my $src_path = $self->{src_path};

        # Make output file name
	my $file_time = file_original_time($file);
	my $dest_file = strftime($self->{dest_path}, localtime($file_time));
        my @parts = ($file =~ /^(.*?)([^\/]*?)(\.[^.\/]*)?$/);
        $parts[2] = $parts[2] ? substr($parts[2], 1) : '';
        $parts[0] = substr($parts[0], length($src_path));
        foreach my $key ('d','f','e') {
                my $val = shift @parts;
                while ($dest_file =~ /%$key/g) {
                        $dest_file =~ s/%$key/$val/;
                }
        }
        $dest_file = canonpath($dest_file);

#        print "\t\t$file -> $dest_file\n" if $verbose;
        # Create destination dir
        mkpath(dirname($dest_file), 0, 0755);
			
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
            }
            utime($file_time, $file_time, $dest_file);
            undef $writed_file;
        }
        return 1;
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
    
    sub cleanup
    {
        unlink($writed_file) if defined $writed_file && -f $writed_file;
    }
    
    sub END
    {
        cleanup;
    }
}