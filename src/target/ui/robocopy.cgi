#!/usr/bin/perl -w

use strict;
use warnings;
use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use JSON::XS;

BEGIN {
    my $exeDir = ($0 =~ /(.*)[\\\/]/) ? $1 : '.';
    
    # add lib directory at start of include path
    unshift @INC, "$exeDir/../bin";
    unshift @INC, "/var/packages/robocopy/target/bin";

    require "config.pl";
}

my $user;
if (open (IN,"/usr/syno/synoman/webman/modules/authenticate.cgi|")) {
	$user=<IN>;
	chop($user);
	close(IN);
}
if ($user eq '') {
#	print "Status: 403 Forbidden\n";
#	print "Content-type: text/plain; charset=UTF-8\n\n";
	print "403 Forbidden\n";
	exit;
}

my %query;

if ($ENV{'REQUEST_METHOD'} eq "POST") {
	my $buffer;
	read(STDIN, $buffer, $ENV{"CONTENT_LENGTH"});
	%query = parse_query($buffer);
}
elsif ($ENV{REQUEST_METHOD} eq 'GET') {
	%query = parse_query($ENV{QUERY_STRING});
}

my $func_name = 'action_' . lc($ENV{'REQUEST_METHOD'});
$func_name .= '_' . $query{action} if exists $query{action};
if (defined &$func_name) {
	&{\&{$func_name}}(%query);
	exit;
}

#print "Status: 404 Not found\n";
print "Content-type: text/plain; charset=UTF-8\n\n";
print "Method: \"$func_name\" not found".
print "404 Not found\n";

#foreach (sort keys %ENV) { print "$_: $ENV{$_}\n"; }

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
	print to_json {'data' => \@share_list, 'total' => scalar(@share_list)};
}

sub _action_get_demo
{
	my $cfg = config_demo();
	write_cfg($cfg, DEFAULT_CONFIG);
	print "Content-type: application/json; charset=UTF-8\n\n";
	print to_json {'data' => $cfg, 'total' => scalar(@$cfg)};
}

sub action_post_list
{
	my %params = @_;
	#TODO
#	if (!isset($params['start'])) $params['start'] = 0;
#	if (!isset($params['limit'])) $params['limit'] = count($cfg);
	my $cfg = read_cfg(DEFAULT_CONFIG);

	print "Content-type: application/json; charset=UTF-8\n\n";
	if (defined($cfg)) {
		print to_json {'data' => $cfg, 'total' => scalar(@$cfg)};
	}
	else {
		print '{"data":null,"total":0}';
	}
}

sub action_post_add
{
	my %rule = get_rule(@_);
	$rule{'id'} = rule_new_id();
	my $cfg = read_cfg(DEFAULT_CONFIG);
	push @$cfg, \%rule;
	write_cfg($cfg, DEFAULT_CONFIG);
	print "Content-type: application/json; charset=UTF-8\n\n";
	print to_json {'data' => \%rule, 'success' => JSON::XS::true};
}

sub action_post_edit
{
	my %rule = get_rule(@_);
	print "Content-type: application/json; charset=UTF-8\n\n";
	unless (exists $rule{id}) {
		print '{"errinfo" : {"key" : "invalid_id", "sec" : "error"}, "success" : false}';
		return ;
	}
	my $cfg = read_cfg(DEFAULT_CONFIG);
	for (my $i = $#{$cfg}; $i>=0; $i--) {
		if ($cfg->[$i]->{'id'} == $rule{id}) {
			$cfg->[$i] = \%rule;
			write_cfg($cfg, DEFAULT_CONFIG);
			print '{"data":null, "success":true}';
			return;
		}
	}
	print '{"errinfo" : {"key" : "not_found", "sec" : "error"}, "success" : false}';
}

sub action_post_remove 
{
	my %params = @_;
	print "Content-type: application/json; charset=UTF-8\n\n";
	unless (exists $params{id}) {
		print '{"errinfo" : {"key" : "invalid_id", "sec" : "error"}, "success" : false}';
		return ;
	}
	my $cfg = read_cfg(DEFAULT_CONFIG);
	for (my $i = $#{$cfg}; $i>=0; $i--) {
		if ($cfg->[$i]->{'id'} == $params{id}) {
			splice(@$cfg, $i, 1);
			write_cfg($cfg, DEFAULT_CONFIG);
			print '{"data":null, "success":true}';
			return;
		}
	}
	print '{"errinfo" : {"key" : "not_found", "sec" : "error"}, "success" : false}';
}

sub action_post_run
{
	my %params = @_;
	unless (exists $params{folders}) {
		print '{"errinfo" : {"key" : "invalid_params", "sec" : "error"}, "success" : false}';
		return;
	}

	my $parent = $$;
	my $pid;
	unless ($pid = fork()) {
		# Child process goes here
		# $parent is parent and $$ is child
		close(STDOUT);
		close(STDERR);
		close(STDIN);
		exec('robocopy', split(/\|/, $params{folders}));
		exit();
	}
	# Parent process goes here
	# $pid is child, $$ is parent
	print "Content-type: application/json; charset=UTF-8\n\n";
	print '{"data" : {"pid" : ' . $pid . '}, "success" : true}';
}

#sub urldecode {    #очень полезная функция декодировани
#	my ($val)=@_;  #запроса,будет почти в каждой вашей CGI-программе
#	$val =~ tr/+/ /;
#	$val =~ s/%([a-fA-F0-9]{2})/pack('C',hex($1))/ge;
#	return $val;
#}

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
