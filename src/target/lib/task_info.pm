#!/usr/bin/perl
#
# @File task_info.pm
# @Author vitalys
# @Created Aug 1, 2016 1:32:45 PM
#

package task_info; {

    use strict;
    use JSON::XS;
    use File::Basename;
    use File::Spec::Functions;
#    use File::Glob;
    use File::Path;
    
    use constant FILES_PATH  => '/tmp/RCTaskMngr/';

    BEGIN {
        my $mask = umask(0);
        mkpath(FILES_PATH, 0, 0777);
        umask($mask);
    }
    
    1;
    
    sub new($;$)
    {
        my($class, $user) = @_;
        my $epoc = time();
        my $rnd = int(rand(4294967296));

        # создаем хэш
        my $self = {
            id => sprintf("%08lX%08X", $epoc, $rnd),
            progress => 0,
            finished => 0
        };
        $self->{user} = $user if defined($user);
        
        # хэш превращается, превращается... в объект
        bless $self, $class;
       
        return $self;
    }
    
    sub load($;$)
    {
        my ($taskid, $user) = @_;
        return undef unless defined $taskid;
        
        my $file = filename($taskid, $user);
        return undef unless -f $file;

        my $text = do {
            local $/ = undef;
            open my $fh, "<", $file || die "could not open $file: $!";
            <$fh>;
        };
        my $self = decode_json $text;
        $self = {} unless ref($self) eq 'HASH';
        $self->{id} = $taskid;
        $self->{user} = $user if defined($user);
        bless $self, __PACKAGE__;
       
        return $self;
    }

    #####################################################################
    # properties
    sub id {
        my ($self) = @_;
        return $self->{id};
    }

    sub progress {
        my ($self, $value) = @_;
        $self->{progress} = 0 + $value if defined $value;
        return 0 unless defined $self->{progress};
        return $self->{progress};
    }

    sub finished {
        my ($self, $value) = @_;
        $self->{finished} = int($value) if defined $value;
        return 0 unless defined $self->{finished};
        return int($self->{finished});
    }
    

    sub data {
        my ($self, $value) = @_;
        $self->{data} = $value if defined $value;
        return $self->{data};
    }

    #####################################################################
    # methods
    sub filename($;$) 
    {
        my ($taskid, $user) = @_;
        return undef unless defined $taskid;
        
        my $file = FILES_PATH;
        $file = catdir($file, $user) if defined $user;
        $file = catfile($file, $taskid);
        return $file;
    }

    sub update($)
    {
        my ($self) = @_;
        my $file = filename($self->{id}, $self->{user});
#       umask(0);
        mkpath(dirname($file), 0, 0777);
        my $text = encode_json {
            "finished" => $self->{finished},
            "progress" => $self->{progress},
            "data" => $self->{data}
        };

        open my $fh, ">", $file || die "could not write $file: $!";
        print $fh $text;
        close $fh;
        
#        return 1;
    }
    
    sub remove($)
    {
        my ($self, $user) = @_;
        
#        return unless $self->finished;
        
        my $file = filename($self->{id}, $self->{user});
        return unless -f $file;
        
        unlink($file) || die "could not remove $file: $!";
    }
    
    sub set_finished($)
    {
        my ($self) = @_;
        $self->progress(1);
        $self->finished(1);
        $self->update();
    }
}

