#!/usr/bin/perl -w

use strict;
use warnings;
use JSON::XS;
use File::Basename;
use File::Path;

BEGIN {
    my $scriptDir = dirname($0);
    
    # add lib directory at start of include path
    unshift @INC, "$scriptDir/../lib";
    unshift @INC, "/var/packages/robocopy/target/lib";
}
#use FindBin qw($Bin);
#use lib "$Bin/../lib";

use rule;
use rule_processor;
use Syno;
use task_info;
use integration;

use Data::Dumper;

my $user;
#if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
#    $user=<IN>;
#    chop($user);
#    close(IN);
#}
#if ($user eq '') {
#	print "Status: 403 Forbidden\n";
#	print "Content-type: text/plain; charset=UTF-8\n\n";
#    print "403 Forbidden\n";
#    exit -1;
#}

my %query;
my $method;

if (defined $ENV{'REQUEST_METHOD'}) {
    $method = $ENV{'REQUEST_METHOD'};
    if ($method eq "POST") {
        my $buffer;
        read(STDIN, $buffer, $ENV{"CONTENT_LENGTH"});
        %query = parse_query($buffer);
    }
    elsif ($method eq 'GET') {
        %query = parse_query($ENV{QUERY_STRING});
    }
}
else {
    $method = $ARGV[0];
    %query = parse_query($ARGV[1]);
    print Dumper \%query;
}

my $func_name = 'action_' . lc($method);
$func_name .= '_' . lc($query{action}) if exists $query{action};
if (defined &$func_name) {
    &{\&{$func_name}}(%query);
    exit;
}

#print "HTTP/1.0 404 Not found\n";
#print "Status: 404 Not found\n";
#print "Content-type: text/plain; charset=UTF-8\n\n";
#print "Method \"$func_name\" not found".
exit -1;

sub parse_query
{
	my $query = shift;
	my %result;
	
	return %result unless defined $query;

	foreach my $part (split(/\&/, $query)) {
		my ($name, $value) = split(/=/, $part);
		$value =~ tr/+/ /;
		$value =~ s/%([a-fA-F0-9]{2})/pack('C',hex($1))/ge;
		$result{$name} = $value;
	}
	return %result;
}

sub print_json($)
{
    print JSON::XS->new->utf8->convert_blessed->encode(@_);
}

sub print_error
{
    my ($error) = @_;
    $error = 'error_unknown' unless defined $error;
    print '{"errinfo" : {"key" : "' . $error . '", "sec" : "error"}, "success" : false}';
}

##############################################################################
# Rules

sub action_post_shared
{
    my @share_list;
    foreach my $name (`/usr/syno/sbin/synoshare --enum local | tail -n+3`) {
        $name =~ s/\n//g;
        my $comment = '';
        if (`/usr/syno/sbin/synoshare --get $name` =~ /Comment.*\[(.*?)\]/) {
            $comment = $1;
        }
        push @share_list, {'name' => $name, 'comment' => $comment};
    }
    print "Content-type: application/json; charset=UTF-8\n\n";
    print encode_json {'data' => \@share_list, 'total' => scalar(@share_list)};
}

sub action_get_shared
{
    my @share_list;
    foreach my $name (`/usr/syno/sbin/synoshare --enum local | tail -n+3`) {
        $name =~ s/\n//g;
        my $comment = '';
        if (`/usr/syno/sbin/synoshare --get $name` =~ /Comment.*\[(.*?)\]/) {
            $comment = $1;
        }
        push @share_list, {'name' => $name, 'comment' => $comment};
    }
    print "Content-type: application/json; charset=UTF-8\n\n";
    print encode_json {'data' => \@share_list, 'total' => scalar(@share_list)};
}

sub _action_get_demo
{
    my $cfg = rule::demo_list;

    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($cfg)) {
        print rule::obj_to_json {'data' => $cfg, 'total' => scalar(@$cfg)};
    }
    else {
        print '{"data":null,"total":0}';
    }
}

sub action_post_list
{
    my %params = @_;
    #TODO
#	if (!isset($params['start'])) $params['start'] = 0;
#	if (!isset($params['limit'])) $params['limit'] = count($cfg);
    my $cfg = rule::load_list();

    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($cfg)) {
        print_json {'data' => $cfg, 'total' => scalar(@$cfg)};
    }
    else {
        print '{"data":null,"total":0}';
    }
}

sub action_get_list
{
    my %params = @_;
    #TODO
#	if (!isset($params['start'])) $params['start'] = 0;
#	if (!isset($params['limit'])) $params['limit'] = count($cfg);
    my $cfg = rule::load_list();

    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($cfg)) {
        print_json {'data' => $cfg, 'total' => scalar(@$cfg)};
    }
    else {
        print '{"data":null,"total":0}';
    }
}

sub action_post_add
{
    my %params = @_;
    print "Content-type: application/json; charset=UTF-8\n\n";
    my $rule = new rule(\%params);
    my $cfg = rule::load_list();
    push @$cfg, $rule;
    rule::save_list($cfg);
    
    print_json {'data' => $rule, 'success' => JSON::XS::true};
}

sub action_post_edit
{
    my %params = @_;
    print "Content-type: application/json; charset=UTF-8\n\n";
    unless (exists $params{id}) {
        print_error('invalid_id');
        return ;
    }
    my $rule = rule::parse(\%params);
    
    my $cfg = rule::load_list();
    for (my $i = $#{$cfg}; $i>=0; $i--) {
        if ($cfg->[$i]->{'id'} == $rule->id()) {
            $cfg->[$i] = $rule;
            rule::save_list($cfg);
            print '{"data":null, "success":true}';
            return;
        }
    }
    print_error('not_found');
}

sub action_post_remove 
{
    my %params = @_;
    print "Content-type: application/json; charset=UTF-8\n\n";
    unless (exists $params{id}) {
        print_error('invalid_id');
        return ;
    }
    my $cfg = rule::load_list();
    for (my $i = $#{$cfg}; $i>=0; $i--) {
        if ($cfg->[$i]->{'id'} == $params{id}) {
            splice(@$cfg, $i, 1);
            rule::save_list($cfg);
            print '{"data":null, "success":true}';
            return;
        }
    }
    print_error('not_found');
}

##############################################################################
# Execution
sub action_post_run
{
    my %params = @_;
    my $epoc = time();
    my $timeout = 60;
    $timeout = int($params{timeout}) if exists $params{timeout} && int($params{timeout}) > 0;
    print "Content-type: application/json; charset=UTF-8\n\n";

    # check folders parameter
    unless (exists $params{folders}) {
        print_error('invalid_params');
        exit;
    }

    my @dirs = split(/\|/, $params{folders});
    
    # load rules
    my $cfg = rule::load_list(undef, 'priority');
    unless (defined($cfg)) {
        print_error('invalid_params');
        exit;
    }
    
    if (exists $params{src_remove}) {
        for my $rule (@$cfg) {
            $rule->set({
                'src_remove' => $params{src_remove}
            })
        }
    }

#print Dumper \$cfg;
#exit; 
    
    my $task = new task_info($user);
    my $data = {};
    $task->data($data);
    
    my $pid;
    # TODO check PID file /val/run/robocopy.pid
   
    if (!defined($pid = fork)) {
        print '{"progress":0,"running":0,"success":false}';
        exit;
    }
    if ($pid) {
        print '{"progress":0,"running":1,"success":true,"taskid":"' . $task->id . '"}';
        exit;
    }
    
    # TODO create PID file /val/run/robocopy.pid
    
    close(STDOUT);
    close(STDERR);
    close(STDIN);

    $SIG{TERM} = sub {
        rule_processor::cleanup();
        $task->remove($user) if defined $task;
#        Syno::notify('Aborted process directories "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy');
        Syno::log('Aborted process directories "' . join(', ', map {basename($_)} @dirs). "\".");
        exit 255;
    };

    $data->{pid} = $$;
    $task->update($user);
    
    # Prepare for work
    my @workers;
    my $total_size = 0;
    my $error;

    for my $rule (@$cfg) {
        for my $dir (@dirs) {
            # Create processor
            my $processor = new rule_processor($rule);
            if ($processor->prepare($dir, \$error)) {
                my $size;
                my $files = $processor->find_files(\$size);
                if (@$files > 0) {
                    $total_size += $size;
                    push @workers, {'processor' => $processor,
                                    'files' => $files,
                                    'size' => $size
                                    };
                }
            }
            else {
                Syno::log($error, 'warn');
            }
        }
    }

    # Process files
    my $processed = 0;
    my $error_count = 0;
    for my $worker (@workers) {
        my $processor = $worker->{'processor'};
        my $files_size = $worker->{'size'};
        for my $file (@{$worker->{'files'}}) {
            # Update task info
            $data->{prule} = $processor->description();
            $data->{pfile} = $file;
            $data->{pdir} = $processor->prepared_path();
            $task->progress($processed / $total_size);
            $task->update();
            #
            my $size = -s $file;
            $processed += $size;
            $files_size -= $size;
            # process file
#            sleep 3;
            unless ($processor->process_file($file, \$error)) {
                Syno::log($error, 'warn');
                ++$error_count;
                #TODO finish task if many error
            }
        }
        $processed += $files_size;
    }
    
    # Update task info (FINISHED) 
    $task->set_finished();

#    Syno::notify('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy') if $total_size;
    Syno::log('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".");
}

sub action_get_readprogress
{
    my %params = @_;
    print "Content-type: application/json; charset=UTF-8\n\n";
    unless (exists $params{taskid}) {
        print_error('invalid_params');
        return;
    }
    my $taskid = $params{taskid};
    my $task = task_info::load($taskid, $user);
    unless (defined($task)) {
        print '{"finished":true,"success":false}';
        exit;
    }
    print encode_json({
        "data" => $task->data(),
        "progress" => $task->progress(),
        "finished" => $task->finished(),
        "success" => 1
    });
    $task->remove($user) if $task->finished;
}

sub action_get_cancelprogress
{
    my %params = @_;
    print "Content-type: application/json; charset=UTF-8\n\n";
    unless (exists $params{taskid}) {
        print_error('invalid_params');
        return;
    }
    my $taskid = $params{taskid};
    my $task = task_info::load($taskid, $user);
    unless (defined($task)) {
        print '{"finished":true,"success":false}';
        exit;
    }

    my $data = $task->data() || {};
    my $pid = $data->{pid};
    kill('TERM', $pid) if defined($pid);

    $data->{result} = 'cancel';
    $task->remove($user);

    print encode_json({
        "data" => $task->data(),
        "progress" => $task->progress(),
        "finished" => $task->finished(),
        "success" => 1
    });
}

##############################################################################
# Configuration
sub action_get_config
{
    my $after_usbcopy = integration::is_run_after_usbcopy;
    my $on_attach_disk = integration::is_run_on_disk_attach;
    
#    my $conf = ini_read(DEFAULT_GLOBALS);
#    if (defined $conf->{global}) {
#        $after_usbcopy = 1 if $conf->{global}->{after_usbcopy} eq 'yes';
#        $on_attach_disk = 1 if $conf->{global}->{on_attach_disk} eq 'yes';
#    }
    
    print "Content-type: application/json; charset=UTF-8\n\n";
    print '{"data" : {"after_usbcopy" : ' . $after_usbcopy . ', "on_attach_disk" : ' . $on_attach_disk . '}, "success" : true}';
}

sub action_post_config
{
    my %params = @_;
    my $after_usbcopy = integration::is_run_after_usbcopy;
    my $on_attach_disk = integration::is_run_on_disk_attach;

    print "Content-type: application/json; charset=UTF-8\n\n";
    if ($params{after_usbcopy} =~ /^(yes|true|1)$/) {
        unless ($after_usbcopy) {
#            integration::set_run_after_usbcopy();
            $after_usbcopy = integration::is_run_after_usbcopy;
        }
    }
    else {
        if ($after_usbcopy) {
#            integration::remove_run_after_usbcopy();
            $after_usbcopy = integration::is_run_after_usbcopy;
        }
    }
    
    if ($params{on_attach_disk} =~ /^(yes|true|1)$/) {
        unless ($on_attach_disk) {
#            integration::set_run_on_disk_attach();
            $on_attach_disk = integration::is_run_on_disk_attach;
        }
    }
    else {
        if ($on_attach_disk) {
#            integration::remove_run_on_disk_attach();
            $on_attach_disk = integration::is_run_on_disk_attach;
        }
    }

#    print '{"errinfo" : {"key" : "invalid_params", "sec" : "error"}, "success" : false}';

#    my $conf = ini_read(DEFAULT_GLOBALS);
#    $conf->{global}->{after_usbcopy} = $after_usbcopy;
#    $conf->{global}->{on_attach_disk} = $on_attach_disk;
#    ini_write(DEFAULT_GLOBALS, $conf);
#    
    print '{"data" : {"after_usbcopy" : ' . $after_usbcopy . ', "on_attach_disk" : ' . $on_attach_disk . '}, "success" : true}';
}

###
sub action_get_test
{
    my %params = @_;
    print "Content-type: text/plain; charset=UTF-8\n\n";
#    print Dumper \%params;
#    local $SIG{__DIE__} = sub {
#        my $message = shift;
#        print "WARN: $message\n";
#    };    
#    action_post_edit %params;
#    action_post_config %params;
#    print "$Bin/../lib\n";
    my $info = `whoami`;
    print "Current user: $info\n";

    my @shares = (`/usr/syno/sbin/synoshare --enum local | tail -n+3`);
    print "Shares:\n @shares\n";

    my $scriptDir = dirname($0);
    print  "$scriptDir/../lib\n";
    print  "/var/packages/robocopy/target/lib\n";
    print Dumper \%ENV;
}


