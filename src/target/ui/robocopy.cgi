#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;
use Encode;
#use Encode::Locale;
use JSON::XS;
use File::Basename;
use File::Path;
#use open ':std' => ':utf8';
#use open qw(:std :utf8);
use List::Util qw(min max);

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
if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
    $user=<IN>;
    close(IN);
    chop($user) if defined($user);
}

my %query;
my $method;

if (-t) { # see IO::Interactive
    # is terminal mode
    binmode(STDIN, ":utf8");
    binmode(STDOUT, ":utf8");
    binmode(STDERR, ":utf8");

    $user=`whoami`;
    chop($user) if defined($user);
    $method = $ARGV[0];
    %query = parse_query($ARGV[1]) if defined $ARGV[1];
}
else {
    $method = $ENV{'REQUEST_METHOD'} if defined $ENV{'REQUEST_METHOD'};
    if ($method eq "POST") {
        my $buffer;
        read(STDIN, $buffer, $ENV{"CONTENT_LENGTH"});
        %query = parse_query($buffer);
    }
    elsif ($method eq 'GET') {
        %query = parse_query($ENV{QUERY_STRING});
    }
}

if ($user eq '') {
    print "Status: 403 Forbidden\n";
    print "Content-type: text/plain; charset=UTF-8\n\n";
    print "403 Forbidden\n";
    exit;
}


my $func_name = 'action';
$func_name .= '_' . lc($method) if defined $method;
$func_name .= '_' . lc($query{action}) if exists $query{action};
if (defined &$func_name) {
    &{\&{$func_name}}(%query);
    exit;
}

#print "HTTP/1.0 404 Not found\n";
print "Status: 404 Not found\n";
print "Content-type: text/plain; charset=UTF-8\n\n";
print "Method \"$func_name\" not found\n";
exit;

sub parse_query
{
    my $query = shift;
    return undef unless defined $query;
    
    my %result;
#    $query = decode("UTF-8", $query);

    return %result unless defined $query;
    utf8::downgrade($query, 1);
    
    foreach my $part (split(/\&/, $query)) {
        my ($name, $value) = split(/=/, $part);
#        print STDERR "$name = '$value'", (utf8::is_utf8($value) ? "[UTF-8]" : "[bytes]"), "\n";
#        #$value =~ tr/+/ /;
        $value =~ y/+/\x20/;
#        print STDERR "\t'$value'", (utf8::is_utf8($value) ? "[UTF-8]" : "[bytes]"), "\n";
        $value =~ s/%([0-9A-Za-z]{2})/pack('C',hex($1))/ge;
#        print STDERR "\t'$value'", (utf8::is_utf8($value) ? "[UTF-8]" : "[bytes]"), "\n";
#        $value = decode("UTF-8", $value);
        utf8::decode($value);
#        print STDERR "\t'$value'", (utf8::is_utf8($value) ? "[UTF-8]" : "[bytes]"), "\n";
        $result{$name} = $value;
    }
    return %result;
}

sub print_json($)
{
    print decode("UTF-8", JSON::XS->new->utf8->convert_blessed->encode(@_));
}

sub print_error
{
    my ($error) = @_;
    $error = 'error_unknown' unless defined $error;
    print '{"errinfo" : {"key" : "' . $error . '", "sec" : "error"}, "success" : false}';
}

##############################################################################
# Rules

sub action_post_share_list
{
    my $share_list = Syno::share_list();
    print "Content-type: application/json; charset=UTF-8\n\n";
    print_json {'data' => $share_list, 'total' => scalar(@$share_list)};
}

sub action_get_share_list
{
    my $share_list = Syno::share_list();
    print "Content-type: application/json; charset=UTF-8\n\n";
    print_json {'data' => $share_list, 'total' => scalar(@$share_list)};
}

sub _action_get_demo
{
    my $cfg = rule::demo_list;

    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($cfg)) {
        print_json {'data' => $cfg, 'total' => scalar(@$cfg)};
    }
    else {
        print '{"data":null,"total":0}';
    }
}

sub action_post_rule_list
{
    _action_rule_list(@_);
}
sub action_get_rule_list
{
    _action_rule_list(@_);
}

sub __action_rule_list
{
    my %params = @_;
    my $cfg = rule::load_list();

    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($cfg)) {
        print_json {'data' => $cfg, 'total' => scalar(@$cfg)};
    }
    else {
        print '{"data":null,"total":0}';
    }
}

sub _action_rule_list
{
    my %params = @_;
    my $cfg = rule::load_list();
    
    print "Content-type: application/json; charset=UTF-8\n\n";

    unless (defined $cfg) {
        print '{"data":null,"total":0}';
        return;
    }
    
    my $total = scalar(@$cfg);

    my $start;
    my $limit;
    $start = int($params{'start'}) if exists($params{'start'});
    $start = 0 unless defined $start;
    $start = 0 if ($start < 0) || ($start > $total);
    
    $limit = int($params{'limit'}) if exists($params{'limit'});
    $limit = $total - $start unless defined $limit;
    $limit = $total - $start if ($limit < 0) || ($limit > ($total - $start));
    

    my @result = splice @$cfg, $start, $limit;

    print_json {'data' => \@result, 'total' => $total};
}

sub action_post_rule_add
{
    my %params = @_;
    # TODO: Check share folder
    print "Content-type: application/json; charset=UTF-8\n\n";
    my $rule = new rule(\%params);
    my $cfg = rule::load_list();
    push @$cfg, $rule;
    rule::save_list($cfg);
    
    print_json {'data' => $rule, 'success' => JSON::XS::true};
}

sub action_post_rule_edit
{
    my %params = @_;
    # TODO: Check share folder
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
            print_json {'data' => $rule, 'success' => JSON::XS::true};
            return;
        }
    }
    print_error('not_found');
}

sub action_post_rule_remove 
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
sub action_post_task_run
{
    my %params = @_;
    my $epoc = time();
#    my $timeout = 60;
#    $timeout = int($params{timeout}) if exists $params{timeout} && int($params{timeout}) > 0;
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
        foreach my $rule (@$cfg) {
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
    $task->write();
    
    # Prepare for work
    my @workers;
    my $total_size = 0;
    my $error;

    foreach my $rule (@$cfg) {
        foreach my $dir (@dirs) {
            # Create processor
            my $processor = new rule_processor($rule);
            $processor->user($user) if defined $user;
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
    foreach my $worker (@workers) {
        my $processor = $worker->{'processor'};
        my $files_size = $worker->{'size'};
        foreach my $file (@{$worker->{'files'}}) {
            # Update task info
            $data->{prule} = $processor->description();
            $data->{pfile} = $file;
            $data->{pdir} = $processor->prepared_path();
            $task->progress($processed / $total_size);
            $task->write();
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

sub action_get_task_progress
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
    print_json({
        "data" => $task->data(),
        "progress" => $task->progress(),
        "finished" => $task->finished(),
        "success" => 1
    });
    $task->remove($user) if $task->finished;
}

sub action_get_task_cancel
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

    print_json({
        "data" => $task->data(),
        "progress" => $task->progress(),
        "finished" => $task->finished(),
        "success" => 1
    });
}

sub action_post_task_list
{
    my %params = @_;
    my $list = task_info::load_list($user);
    my @result;


    print "Content-type: application/json; charset=UTF-8\n\n";
    if (defined($list)) {
        foreach my $task (@$list) {
            if ($task->finished()) {
                $task->remove();
            }
            else {
                push @result, $task;
            }
        }
        print_json {'data' => \@result, 'total' => scalar(@result), 'success' => 1};
    }
    else {
        print '{"data":null,"total":0, "success":true}';
    }
}

##############################################################################
# Configuration
sub action_get_integration
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

sub action_post_integration
{
    my %params = @_;
    my $after_usbcopy = integration::is_run_after_usbcopy;
    my $on_attach_disk = integration::is_run_on_disk_attach;

    print "Content-type: application/json; charset=UTF-8\n\n";
    if ($params{after_usbcopy} =~ /^(yes|true|1)$/) {
        unless ($after_usbcopy) {
            integration::set_run_after_usbcopy();
            $after_usbcopy = integration::is_run_after_usbcopy;
        }
    }
    else {
        if ($after_usbcopy) {
            integration::remove_run_after_usbcopy();
            $after_usbcopy = integration::is_run_after_usbcopy;
        }
    }
    
    if ($params{on_attach_disk} =~ /^(yes|true|1)$/) {
        unless ($on_attach_disk) {
            integration::set_run_on_disk_attach();
            $on_attach_disk = integration::is_run_on_disk_attach;
        }
    }
    else {
        if ($on_attach_disk) {
            integration::remove_run_on_disk_attach();
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

##############################################################################
# Tests
sub print_str($$;@)
{
    my ($text, $str, $end_line) = @_;
    print "$text'$str' [", (utf8::is_utf8($str) ? "UTF-8" : "bytes"), "]";
    print $end_line if defined $end_line;
}

sub print_array_hash(\@$;$@)
{
    my ($arr, $columns, $titles, @suffix) = @_;

    my %colWidth = ();
    my %colNames = ();
    # calc columns width
    for (my $i = 0; $i <= $#{$columns}; $i++) {
        my $key = $columns->[$i];
        my $title = $key;
        $title =~ tr/_/ /;
        $title  =~ s/(\w+)/\u\L$1/g;

        $title = $titles->[$i] if defined($titles) && defined($titles->[$i]);
        $colWidth{$key} = max (map length, map( {$_->{$key}} @$arr), $title);
        $colNames{$key} = $title;
    }

    # print  titles 
    foreach my $key (@$columns) {
        printf( "  %-*s", 
            $colWidth{$key}, $colNames{$key});
    }
    print("\n");
    # print delimiter
    foreach my $key (@$columns) {
        printf( "  %-*s", 
            $colWidth{$key}, '-' x $colWidth{$key});
    }
    print("\n");
    # print data
    foreach my $item (@$arr) {
        foreach my $key (@$columns) {
            printf( "  %-*s", 
                $colWidth{$key}, $item->{$key});
        }
        print("\n");
    }
    print @suffix;
}

sub action_post_test {
    _action_test(@_);
}

sub action_get_test {
    _action_test(@_);
}

sub _action_test
{
    my %params = @_;
    print "Content-type: text/plain; charset=UTF-8\n\n";
    
    use PerlIO;
    print "STDIN = ", join(" ", PerlIO::get_layers(STDIN)), "\n";
    print "STDOUT = ", join(" ", PerlIO::get_layers(STDOUT)), "\n";
    print "STDERR = ", join(" ", PerlIO::get_layers(STDERR)), "\n\n";

    print "Parameters:\n", Dumper(\%params), "\n\n";

#    print_str "Param:", $params{dest_folder}, "\n";

#    print "$Bin/../lib\n";
    my $info = `whoami`;
    chop($info);
    print "Current user: $info\n";
    print "Authenticated user: $user\n" if defined $user;

    my $scriptDir = dirname($0);
    print  "$scriptDir/../lib\n";
    print  "/var/packages/robocopy/target/lib\n";
#    print "ENV:\n", Dumper(\%ENV), "\n\n";

    my $shares;
    $shares = Syno::share_list();
    if (defined($shares)) {
        print "\nShares:\n";
        print_array_hash(@$shares, ['name', 'real_path', 'comment'], ['Name', 'Path', 'Comment']);
        print "\n\n";
    }

    

#    my $task = new task_info($user);
#    my $rus_text = decode("UTF-8", "пример Русского текста");
    
#    print "$rus_text\n";
#    print "UTF-8 flag set!\n" if utf8::is_utf8($rus_text);
#    print "--\n";
#    my $data = { 'text' => $rus_text };
#    $task->data($data);
#    print Dumper \$task;
#    $task->write();
    
#    exit;
    
    
#    my @task_list = task_info::load_list($user);
#    print Dumper \@task_list;
    
#    $task->remove();

#    @task_list = task_info::load_list($user);
#    print Dumper \@task_list;

    my $cfg;
    $cfg = rule::load_list(undef, 'priority');
    if (defined($cfg)) {
        print "\nRules:\n";
        print_array_hash(@$cfg, 
            [
                'priority', 
                'src_ext',
                'src_dir',
                'dest_folder',
                'dest_dir',
                'dest_file',
                'dest_ext',
                'description',
                'src_remove'
            ], 
                        [
                'NN', 
                'Ext',
                'From',
                'dest_folder',
                'dest_dir',
                'dest_file',
                'dest_ext',
                'Description',
                'DEL'
            ]);
        print "\n\n";
    }

    if (defined($cfg) && exists($params{folders})) {
        my @dirs = split(/\|/, $params{folders});
        my $dir_count = scalar(@dirs);
        my $error;

        my $task;
#        $task = new task_info($user);
        my $data = {};
        $task->data($data) if defined $task;

        my $rule_count = scalar(@$cfg);
        my $rule_idx = 0;
        foreach my $rule (@$cfg) {
            # Create processor
            print_str "[". $rule->priority()."] - ", $rule->description(), "\n";
            my $processor = new rule_processor($rule);
            my $dir_idx = 0;
            foreach my $dir(@dirs) {
                print_str "  path: ", $dir, "\n";
                if ($processor->prepare($dir, \$error)) {
                    print_str "  Prepared: ", $processor->prepared_path(), "\n";
                    my $size = 0;
                    my @files = $processor->find_files(\$size);
                    my $file_count = scalar(@files);
                    my $file_idx = 0;
                    print "    Found $file_count files\n";
                    foreach my $file (@files) {
                        my $file_size = -s "$file";
                        print_str "    ", $file, " - $file_size\n";
                        if (defined $task) {
                            # Update task info
                            $data->{prule} = $processor->description();
                            $data->{pfile} = $file;
                            $data->{pdir} = $processor->prepared_path();
                            $task->progress(($rule_idx + ($dir_idx + $file_idx / $file_count) / $dir_count) / $rule_count);
                            $task->write();
                            
                            # Read task info
                            my $task_r = task_info::load($task->id, $user);
                            print_str "      task: [" . $task->progress() . "] ", $task_r->data()->{pfile}, "\n";
                        }
                        my $dest_file = $processor->make_dest_file($file);
                        print_str "      -> ", $dest_file, "\n";
                        ++$file_idx;
                    }
                }
                else {
                    print "    Preparing error: '$error'\n";
                }
                ++$rule_idx;
            }
            ++$dir_idx;
        }
        if (defined $task) {
            $task->set_finished();
            $task->remove();
        }
    }
}

