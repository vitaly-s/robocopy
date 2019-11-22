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
            created => $epoc,
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
        
        return task_info::read($file);
    }

    sub read($) {
        my ($file) = @_;
        return undef unless -f $file;

        my $text = do {
            local $/ = undef;
            open my $fh, "<", $file || die "could not open $file: $!";
            <$fh>;
        };
        my $self = JSON::XS->new->utf8->decode($text);
        return undef unless ref($self) eq 'HASH';
        return undef unless defined $self->{id};
        return undef unless defined $self->{created};
        bless $self, __PACKAGE__;
       
        return $self;
    }
    
    sub write($;$)
    {
        my ($self, $file) = @_;
        $file = filename($self->{id}, $self->{user}) unless defined $file;
#       umask(0);
        mkpath(dirname($file), 0, 0777);
        my $text = JSON::XS->new->utf8->convert_blessed->encode($self);

        open my $fh, ">", $file || die "could not write $file: $!";
        print $fh $text;
        close $fh;
        
#        return 1;
    }
    
    sub load_list($)
    {
        my ($user) = @_;
        
        my $folder = FILES_PATH;
        $folder = catdir($folder, $user) if defined $user;

        my $task_list = [];
        if ( -d $folder) {
            my $mask = catfile($folder, "*");
            foreach my $file (glob($mask)) {
                my $task = task_info::read($file);
                push(@$task_list, $task) if defined($task);
            };
        }
        return $task_list;
    }

    sub TO_JSON {
        return { %{ shift() } };
    }

    #####################################################################
    # properties
    sub id {
        my ($self) = @_;
        return $self->{id};
    }

    sub user {
        my ($self, $value) = @_;
        $self->{user} = $value if defined($value);
        return $self->{user};
    }

    sub created {
        my ($self) = @_;
        return $self->{created};
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
        $self->write();
    }
}

