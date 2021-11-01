#!/usr/bin/perl -w

use strict;
require 5.004;
use warnings;
use utf8;
use Encode;
#use Encode::Locale;
use JSON::XS;
use File::Basename;
use File::Path;
#use open ':std' => ':utf8';
#use open qw(:std :utf8);
use POSIX qw(strftime);
use List::Util qw(min max);
use HTTP::Date;


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
use Geo::Coder;
use CityLocator;
use Settings;
use FileInfo;

use Data::Dumper;

my $verbose = 0;
my $user;
# if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
    # $user=<IN>;
    # close(IN);
    # chop($user) if defined($user);
# }

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
    if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
        $user=<IN>;
        close(IN);
        chop($user) if defined($user);
    }

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

open(STDERR, '>>', '/tmp/robocopy.cgi.log') if $verbose;

my $func_name = 'action';
$func_name .= '_' . lc($method) if defined $method;
$func_name .= '_' . lc($query{action}) if exists $query{action};
if (defined &$func_name) {
    eval { &{\&{$func_name}}(%query); }; 
    if ($@) {
        print STDERR "Func '$func_name' raised an exception: $@" if $verbose;
        print "Content-type: application/json; charset=UTF-8\n\n"; 
        print '{"errinfo" : {"key" : "system", "sec" : "error"}, "success" : false}';
    }
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

sub load_settings
{
    my $setting = Settings->new;
    eval { $setting = Settings::load };
    Syno::log("Read setting error: $@", 'warn') if $@;
    $setting;
}

sub configure_locator
{
    my $locator = shift || CityLocator->new();
    my $setting = shift || load_settings;

    $locator->threshold($setting->locator_threshold);
    $locator->language($setting->locator_language);

    return $locator;
}

sub address_format
{
    my %formats = (
        'en' => '(({house} ){road}, )({suburb}, )({city}, )({county}, )({state}, ){country}',
        'fr' => '(({house}, ){road}, )({suburb}, )({city}, )({state}, ){country}',
        'de' => '({road}( {house}), )({suburb}, )({city}, )({state}, ){country}',
        'it' => '({road}( {house}), )({suburb}, )({city}, )({state}, ){country}',
        'es' => '({road}(, {house}), )({suburb}, )({city}, )({state}, ){country}',
        'ru' => '({road}( {house}), )({suburb}, )({city}, |{county}, )({state}, ){country}',
    );
    my $address = shift;
    return undef unless defined $address;
    
    my $setting = shift || load_settings;
    my $language = $address->{countryCode} || $setting->locator_language;
    my $fmt = $formats{$language} || $formats{en};
    return Template::parse { $address->{$_} } $fmt;
}
#sub print_error
#{
#    my ($error) = @_;
#    $error = 'error_unknown' unless defined $error;
#    print '{"errinfo" : {"key" : "' . $error . '", "sec" : "error"}, "success" : false}';
#}

sub PRINT_RESPONSE_HEADER_JSON
{ 
    print "Content-type: application/json; charset=UTF-8\n\n"; 
}

sub ERROR_NOT_FOUND($)
{
    my $value = shift;

    PRINT_RESPONSE_HEADER_JSON;
    print '{"errinfo" : {"key" : "not_found", "sec" : "error", "value":"' . $value . '"}, "success" : false}';
    exit;
}

sub ERROR_INVALID_PARAMS(;$$\@)
{
    my ($name, $value, $details) = @_;
    PRINT_RESPONSE_HEADER_JSON;
    my $errinfo = {'key' => 'invalid_params', 'sec' => 'error'};
    $errinfo->{name} = $name if defined $name;
    $errinfo->{value} = $value if defined $value;
    $errinfo->{details} = $details if defined $details;
    print_json {'errinfo' => $errinfo, 'success' => JSON::XS::false};
    exit;
}

sub ERROR_RUN_TASK($)
{
    my $reason = shift;
    PRINT_RESPONSE_HEADER_JSON;
    print '{"errinfo" : {"key" : "not_run", "sec" : "error", "value":"' . $reason . '"}, "success" : false}';
    exit;
}

sub ERROR_PROCESS_FILE($)
{
    my $file = shift;
    PRINT_RESPONSE_HEADER_JSON;
    print '{"errinfo" : {"key" : "process_file", "sec" : "error", "name":"' . basename($file) . '"}, "success" : false}';
    exit;
}

sub ERROR_PERMISSION_READ($)
{
    my $path = shift;
    PRINT_RESPONSE_HEADER_JSON;
    print '{"errinfo" : {"key" : "permission_read", "sec" : "error", "path":"' . $path . '"}, "success" : false}';
    exit;
}

sub ERROR_PERMISSION_WRITE($)
{
    my $path = shift;
    PRINT_RESPONSE_HEADER_JSON;
    print '{"errinfo" : {"key" : "permission_write", "sec" : "error", "path":"' . $path . '"}, "success" : false}';
    exit;
}

sub RESPONSE_LIST(\@;$)
{
    my ($list, $total) = @_;
    $total = scalar(@$list) unless defined $total;

    PRINT_RESPONSE_HEADER_JSON;
    print_json {'data' => $list, 'total' => $total, 'success' => JSON::XS::true};
    exit;
}

sub RESPONSE(;$)
{
    my $obj = shift;

    PRINT_RESPONSE_HEADER_JSON;
    print_json {'data' => $obj, 'success' => JSON::XS::true};
    exit;
}

sub RESPONSE_TASK($)
{
    my $task = shift;

    PRINT_RESPONSE_HEADER_JSON;
    if (defined $task) {
        print_json({
            'taskid' => $task->id,
            'data' => $task->data(),
            'progress' => $task->progress(),
            'finished' => $task->finished(),
            'success' => JSON::XS::true
        });
    }
    else {
        print '{"finished":true,"success":false}';
    }
    exit;
}
##############################################################################
# Rules

sub _action_share_list
{
    my @share_list = Syno::share_list();
    RESPONSE_LIST(@share_list)
}

sub action_post_share_list
{
    &_action_share_list;
}

sub action_get_share_list
{
    &_action_share_list;
}

sub _action_get_demo
{
    my @cfg = rule::demo_list;
    RESPONSE_LIST(@cfg)
}

sub action_post_rule_list
{
    _action_rule_list(@_);
}
sub action_get_rule_list
{
    _action_rule_list(@_);
}

sub _action_rule_list
{
    my %params = @_;
    my @cfg = rule::load_list();

    my $total = scalar(@cfg);

    my $start;
    my $limit;
    $start = int($params{'start'}) if exists($params{'start'});
    $start = 0 unless defined $start;
    $start = 0 if ($start < 0) || ($start > $total);
    
    $limit = int($params{'limit'}) if exists($params{'limit'});
    $limit = $total - $start unless defined $limit;
    $limit = $total - $start if ($limit < 0) || ($limit > ($total - $start));
    

    my @result = splice(@cfg, $start, $limit);
    RESPONSE_LIST(@result, $total);
}

sub _validate_rule($)
{
    my $rule = shift;
    # Check share folder
    my $syno_folder = Syno::share_path($rule->dest_folder());
    ERROR_INVALID_PARAMS('dest_folder', $rule->dest_folder()) unless defined $syno_folder;
    # Check shared folder pervission
    ERROR_PERMISSION_WRITE('/'.$rule->dest_folder()) unless -w $syno_folder;
    # TODO sCheck dest_dir permissions
    
    # Validate templates
    my @errors;
    ERROR_INVALID_PARAMS('dest_dir', $rule->dest_dir(), @errors) if rule_processor::validate_template($rule->dest_dir(), @errors);
    ERROR_INVALID_PARAMS('dest_file', $rule->dest_file(), @errors) if rule_processor::validate_template($rule->dest_file(), @errors);
    ERROR_INVALID_PARAMS('dest_ext', $rule->dest_ext(), @errors) if rule_processor::validate_template($rule->dest_ext(), @errors);
}

sub action_post_rule_add
{
    my %params = @_;
    my $rule = new rule(\%params);
    
    _validate_rule($rule);

    my @cfg = rule::load_list();
    push @cfg, $rule;
    rule::save_list(@cfg);
    
    RESPONSE($rule);
}


sub action_post_rule_edit
{
    my %params = @_;
    
    ERROR_INVALID_PARAMS('id') unless exists $params{id};

    my $rule = rule::parse(\%params);
    
    _validate_rule($rule);

    my @cfg = rule::load_list();
    for (my $i = $#cfg; $i>=0; $i--) {
        if ($cfg[$i]->id() == $rule->id()) {
            $cfg[$i] = $rule;
            rule::save_list(@cfg);
#            print_json {'data' => $rule, 'success' => JSON::XS::true};
#            return;
            RESPONSE($rule);
        }
    }
#    print_error('not_found');
    ERROR_NOT_FOUND('rule');
}

sub action_post_rule_remove 
{
    my %params = @_;
#    print "Content-type: application/json; charset=UTF-8\n\n";
#    unless (exists $params{id}) {
#        print_error('invalid_id');
#        return ;
#    }
    ERROR_INVALID_PARAMS('id') unless exists $params{id};

    my @cfg = rule::load_list();
    for (my $i = $#cfg; $i>=0; $i--) {
        if ($cfg[$i]->id() == $params{id}) {
            splice(@cfg, $i, 1);
            rule::save_list(@cfg);
            RESPONSE;
#            print '{"data":null, "success":true}';
#            return;
        }
    }
#    print_error('not_found');
    ERROR_NOT_FOUND('rule');
}

sub abs2share($)
{
#    my ($path, $share_list) = @_;
#    $share_list = Syno::share_list() unless defined $share_list;
#    foreach my $share (@$share_list) {
#        my $share_name = $share->{name};
#        my $share_path = $share->{real_path};
#        last if $path =~ s/^$share_path/\/$share_name/;
#    }
    my $path = shift;
    $path =~ s/^\/[^\/]+//o;
    $path;
}

##############################################################################
# Execution
sub action_post_task_run
{
    my %params = @_;
    my $epoc = time();
#    my $timeout = 60;
#    $timeout = int($params{timeout}) if exists $params{timeout} && int($params{timeout}) > 0;
#    print "Content-type: application/json; charset=UTF-8\n\n";

    # check folders parameter
    ERROR_INVALID_PARAMS('folders') unless (exists $params{folders});

    my @dirs = split(/\|/, $params{folders});
    
    # load rules
    my @cfg = rule::load_list(undef, 'priority');
#    unless (defined(@cfg)) {
#        print_error('invalid_params');
#        exit;
#    }
    
    if (exists $params{src_remove}) {
        foreach my $rule (@cfg) {
#            $rule->set({
#                'src_remove' => $params{src_remove}
#            })
            $rule->src_remove($params{src_remove});
        }
    }
    
    # TODO: Check share folder
    foreach my $rule (@cfg) {
        # Validate template
        _validate_rule($rule);
        # Check source permissons
        foreach my $dir (@dirs) {
            ERROR_PERMISSION_READ(abs2share($dir)) unless -r $dir;
            if ($rule->src_remove()) {
                ERROR_PERMISSION_WRITE(abs2share($dir)) unless -w $dir;
            }
        }
    }
    
    my $task = new task_info($user);
    my $data = {};
    $task->data($data);
    
    my $pid;
    # TODO check PID file /val/run/robocopy.pid
   
#    PRINT_RESPONSE_HEADER_JSON;
    if (!defined($pid = fork)) {
        ERROR_RUN_TASK($!);
#        print '{"progress":0,"running":0,"success":false}';
        exit;
    }
    if ($pid) {
        RESPONSE_TASK($task);
#        print '{"progress":0,"running":1,"success":true,"taskid":"' . $task->id . '"}';
        exit;
    }
    
    # TODO create PID file /val/run/robocopy.pid
        

    if ($verbose) {
        my $info = `whoami`;
        chop($info);
        print STDERR 'Start process directories: ' . join(', ', map {basename($_)} @dirs). "\n";
        print STDERR "Current user: $info\n";
        print STDERR "Authenticated user: $user\n" if defined $user;
    }
    else {
        close(STDOUT);
        close(STDERR);
        close(STDIN);
    }

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
    my $total_count = 0;
    my $error;
    my $start_time = time;
    
    my $settings = load_settings;
    my $locator = configure_locator(CityLocator->new(), $settings);


    foreach my $rule (@cfg) {
        print STDERR "Prepare \"$rule->{description}\" [$rule->{src_ext} => $rule->{dest_dir}]\n"
            if $verbose;
        foreach my $dir (@dirs) {
            print STDERR "  $dir\n" if $verbose;
            # Create processor
            my $processor = new rule_processor($rule, $locator);
            $processor->conflict_policy($settings->conflict_policy);
            $processor->compare_mode($settings->compare_mode);
            $processor->user($user) if defined $user;
            if ($processor->prepare($dir, \$error)) {
                print STDERR "    Prepared: ",$processor->prepared_path(),"[",$processor->src_path(),"]\n"
                    if $verbose;
                my $size;
                my $files = $processor->find_files(\$size);
                print STDERR "    Find files ",scalar(@$files), " [$size]\n" if $verbose;
                if (@$files > 0) {
                    $total_size += $size;
                    $total_count += @$files;
                    push @workers, {'processor' => $processor,
                                    'files' => $files,
                                    'size' => $size
                                    };
                }
            }
            else {
                print STDERR "    ERROR: $error\n" if $verbose;
                Syno::log($error, 'warn');
            }
        }
    }

    # Process files
    my $processed_size = 0;
    my $processed_count = 0;
    my $error_count = 0;
    my $start_process_time = time;
    foreach my $worker (@workers) {
        my $processor = $worker->{'processor'};
        my $files_size = $worker->{'size'};
        my $files_count = 0 + @{$worker->{'files'}};
        print STDERR "Process: ".$processor->prepared_path()."\n" if $verbose;
        foreach my $file (@{$worker->{'files'}}) {
            my $current_time = time;
            # Update task info
            print STDERR "  $file\n" if $verbose;
            $data->{prule} = $processor->description();
            $data->{pfile} = $file;
            $data->{pdir} = $processor->prepared_path();
            $data->{total_size} = $total_size;
#            $data->{total_count} = $total_count;
            $data->{processed_size} = $processed_size;
            $data->{processed_count} = $processed_count;
#            $data->{processed_time} = $current_time - $start_time;
            if ($processed_size > 0) {
                $data->{remaining_time} = int(($current_time - $start_time) / $processed_size * ($total_size - $processed_size) + 0.5);
            }
            $task->progress($processed_size / $total_size);
            $task->write();
            #
            my $size = -s $file;
            $processed_size += $size;
            $processed_count += 1;
            
            $files_size -= $size;
            $files_count -= 1;
            # process file
#            sleep 3;
            unless ($processor->process_file($file, \$error)) {
                print STDERR "    ERROR: $error" if $verbose;
                Syno::log($error, 'warn');
                ++$error_count;
                #TODO finish task if many error
            }
        }
        # correct processed files between workers
        $processed_size += $files_size;
        $processed_count += $files_count;
    }
    # Try clear source dirs
    #rule_processor::crear_dir(@dirs);
    # Update task info (FINISHED) 
    $task->set_finished();

    print STDERR 'Finished process directories: ' . join(', ', map {basename($_)} @dirs). "\n" if $verbose;

#    Syno::notify('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".", 'RoboCopy') if $total_size;
    Syno::log('Finished process directories "' . join(', ', map {basename($_)} @dirs). "\".");
}

sub action_get_task_progress
{
    my %params = @_;

    ERROR_INVALID_PARAMS('taskid') unless exists $params{taskid};
    my $taskid = $params{taskid};
    my $task = task_info::load($taskid, $user);
    ERROR_NOT_FOUND('task') unless defined($task);

    $task->remove($user) if $task->finished;
    RESPONSE_TASK($task);
}

sub action_get_task_cancel
{
    my %params = @_;

    ERROR_INVALID_PARAMS('taskid') unless exists $params{taskid};

    my $taskid = $params{taskid};
    my $task = task_info::load($taskid, $user);
    
    ERROR_NOT_FOUND('task') unless defined($task);

    my $data = $task->data() || {};
    my $pid = $data->{pid};
    kill('TERM', $pid) if defined($pid);

    $data->{result} = 'cancel';
    $task->remove($user);
    $task->finished(1);

    RESPONSE_TASK($task);
}

sub action_post_task_list
{
    my %params = @_;
    my @list = task_info::load_list($user);
    my @result;

    foreach my $task (@list) {
        if ($task->finished()) {
            $task->remove();
        }
        else {
            push @result, $task;
        }
    }
    RESPONSE_LIST(@result);
}

##############################################################################
# Configuration
sub action_get_settings
{
    my $setting = Settings::load;
    RESPONSE({
        'run_after_usbcopy' => integration::is_run_after_usbcopy, 
        'run_on_attach_disk' => integration::is_run_on_disk_attach,
        'locator_threshold' => $setting->locator_threshold,
        'locator_language' => $setting->locator_language,
        'conflict_policy' => $setting->conflict_policy,
        'compare_mode' => $setting->compare_mode,
    });
}

sub action_post_settings
{
    my %params = @_;

    # Integration
    if (exists $params{run_after_usbcopy}) {
        my $after_usbcopy = integration::is_run_after_usbcopy;

        if ($params{run_after_usbcopy} =~ /^(yes|true|1)$/) {
            unless ($after_usbcopy) {
                integration::set_run_after_usbcopy();
            }
        }
        else {
            if ($after_usbcopy) {
                integration::remove_run_after_usbcopy();
            }
        }
        $params{run_after_usbcopy} = integration::is_run_after_usbcopy;
    }
    
    if (exists $params{run_on_attach_disk}) {
        my $on_attach_disk = integration::is_run_on_disk_attach;
        if ($params{run_on_attach_disk} =~ /^(yes|true|1)$/) {
            unless ($on_attach_disk) {
                integration::set_run_on_disk_attach();
            }
        }
        else {
            if ($on_attach_disk) {
                integration::remove_run_on_disk_attach();
            }
        }
        $params{run_on_attach_disk} = integration::is_run_on_disk_attach;
    }

    # Other setting
    my $setting = Settings::load;
    $setting->locator_threshold($params{locator_threshold}) if exists $params{locator_threshold};
    $setting->locator_language($params{locator_language}) if exists $params{locator_language};
    $setting->conflict_policy($params{conflict_policy}) if exists $params{conflict_policy};
    $setting->compare_mode($params{compare_mode}) if exists $params{compare_mode};
    
    $setting->save;
    
    RESPONSE(\%params);
}

##############################################################################
# Edit
sub action_get_fileinfo
{
    my %params = @_;

    # check files parameter
    ERROR_INVALID_PARAMS('files') unless (exists $params{files});

    my @files = split(/\|/, $params{files});
    my $settings = load_settings;
    my $locator = configure_locator(Locator->new(), $settings);
#    print STDERR "Locator\n", Dumper($locator), "\n", $locator->locate($self->{latitude}, $self->{longitude});

    my $date;
    my $location;
    my $title;
    my @address_fields = qw/ house road suburb city state country /;
    foreach my $file (@files) {
        ERROR_PROCESS_FILE($file) unless -f $file && -r $file;
        print STDERR "Get fileinfo: $file\n" if $verbose;
        my $info = FileInfo::load($file, $locator);
        my $fl_date = $info->parse_template('{yyyy}-{MM}-{dd}');
        my $fl_title = $info->get_value('title');
#        my $fl_location = ''; 
#        $fl_location = $info->parse_template('({city}, ){country}') unless defined $location && $location eq '';
#        print STDERR $info->parse_template('({city}, ){country}'), "\n\n";
        my $fl_location = $info->get_location();
#        print STDERR "$file\n\tfl_date:$fl_date\n\tfl_title:$fl_title\n\tfl_location:$fl_location\n";

        if (defined $date) {
            $date = '' if defined $fl_date && $fl_date ne $date;
        }
        else {
            $date = $fl_date;
        }
        if (defined $title) {
            $title = '' if defined $fl_title && $fl_title ne $title;
        }
        else {
            $title = $fl_title;
        }
#        if (defined $location) {
#            $location = '' if defined $fl_location && $fl_location ne $location;
#        }
#        else {
#            $location = $fl_location;
#        }
        if (defined $location) {
            if (defined $fl_location) {
                foreach my $fld (@address_fields) {
                    $location->{$fld} = undef unless defined $location->{$fld} 
                        && $fl_location->{$fld} 
                        && $location->{$fld} eq $fl_location->{$fld};
                }
            }
        }
        else {
            $location = $fl_location;
        }
    }
    
    my $location_str = "";
    if (defined $location) {
        $location_str = address_format($location, $settings);
    }
    RESPONSE({
        'date' => $date, 
#        'location' => $location,
        'location' => $location_str,
        'title' => $title
    });
}

sub action_post_fileinfo
{
    my %params = @_;
    # check files parameter
    ERROR_INVALID_PARAMS('files') unless (exists $params{files});

    my @files = split(/\|/, $params{files});
    my $settings = load_settings;
    my $locator = configure_locator(CityLocator->new(), $settings);
    
    my %result = ();
    my $fileInfo = FileInfo::new($locator);
    
    if (defined $params{date}) {
        my $dt = str2time($params{date});
        ERROR_INVALID_PARAMS('date') unless defined $dt;
        $fileInfo->datetime($dt);
        $result{date} = strftime('%Y-%m-%d %H:%M:%S', localtime($dt));
    }
    if (exists $params{location}) {
#        my ($address, $point); 
#        ($address, $point) = $locator->search($params{location});
#        ERROR_INVALID_PARAMS('location') unless defined $address;
        ERROR_INVALID_PARAMS('location') unless $fileInfo->search_location($params{location});
##        print STDERR "Location:\n", $address->as_string(), "\nPoint:\n", Dumper($point), "\n\n";
#        $fileInfo->location($address, $point);
#        $result{location} = $address->as_string();
        my $location = $fileInfo->location;
        $result{location} = (defined $location ? $location->as_string() : undef);
    }
    if (exists $params{title}) {
        my $title = ($params{title} ne '' ? $params{title} : undef);
        $fileInfo->title($title);
        $result{title} = $title;
    }
    if (scalar keys %result) {
        foreach my $file (@files) {
            ERROR_PROCESS_FILE($file) unless -f $file && -w $file;
            print STDERR "Update [" . $file . "]: \n" if $verbose;
            my $res = $fileInfo->update($file);
#            print STDERR "\t".(defined $res ? $res : '<UNDEF>')."\n";
            if ($res != 1) {
                print STDERR "Update [" . $file . "] error.\n" if $verbose;
                ERROR_PROCESS_FILE($file) unless $res;
            }
        }
    }
    RESPONSE(\%result);
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

sub __test_task()
{
    printf "umask: %o\n", umask();
    my $mask = umask(0);
    printf "umask: %o\n", umask();
    mkdir('/tmp/TEST');
    umask($mask);
    
    my $task = new task_info($user);

    my $data = { 'text' => 'demo text' };
    $task->data($data);
    print Dumper \$task;
    $task->write();
    
#    exit;
    
    my @task_list = task_info::load_list($user);
    print Dumper \@task_list;
    
    $task->remove();

    @task_list = task_info::load_list($user);
    print Dumper \@task_list;
}

sub _action_test
{
    my %params = @_;
    print "Content-type: text/plain; charset=UTF-8\n\n";
    
    use PerlIO;
#    print "STDIN = ", join(" ", PerlIO::get_layers(STDIN)), "\n";
#    print "STDOUT = ", join(" ", PerlIO::get_layers(STDOUT)), "\n";
#    print "STDERR = ", join(" ", PerlIO::get_layers(STDERR)), "\n\n";

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

    __test_task();

    my $cfg;
    $cfg = rule::load_list(undef, 'priority');
    if (defined($cfg)) {
        print "\nRules:\n";
        print_array_hash(@$cfg, 
            [
                'priority', 
                'src_ext',
#                'src_dir',
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
#                'From',
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

        my $settings = load_settings;
        my $locator = configure_locator(CityLocator->new(), $settings);

        my $task;
#        $task = new task_info($user);
        my $data = {};
        $task->data($data) if defined $task;

        my $rule_count = scalar(@$cfg);
        my $rule_idx = 0;
        foreach my $rule (@$cfg) {
            # Create processor
            print_str $rule->priority() . ": [" . $rule->src_ext() . "] - ", $rule->description(), "\n";
            
            my $processor = new rule_processor($rule, $locator);
            $processor->conflict_policy($settings->conflict_policy);
            $processor->compare_mode($settings->compare_mode);
            $processor->user($user) if defined $user;

            my $dir_idx = 0;
            foreach my $dir(@dirs) {
                print_str "  path: ", $dir, "\n";
                print "    ", abs2share($dir), "\n";
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
                        print_str "      -> ", $dest_file, "\n" if defined $dest_file;
                        ++$file_idx;
                        if ($params{run}) {
                            my $error;
                            unless ($processor->process_file($file, \$error)) {
                                print_str "      error: ", $error, "\n";
                            }
                            else {
                                print "        Processed\n";
                            }
                        }
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

