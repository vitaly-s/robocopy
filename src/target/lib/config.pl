#!/usr/bin/perl -w

use strict;
use JSON::XS;

use constant DEFAULT_CONFIG    => '/var/packages/robocopy/etc/rules.conf';
use constant CONFIG_FIELDS => {
		'id' => 0,
		'priority' => 0,
		'src_dir' => '',
		'src_ext' => '',
		'dest_folder' => '',
		'dest_dir' => '',
		'dest_file' => '',
		'dest_ext' => '',
		'description' => '',
		'src_remove' => 0
	};

1;

#############################
sub is_number_field
{
	my $key = shift;
	return undef unless exists CONFIG_FIELDS->{$key};
	return 1 if CONFIG_FIELDS->{$key} ne '';
	return 0;
}

sub get_rule
{
	my %params = @_;
	my %rule;
	foreach my $key (keys %{CONFIG_FIELDS()}) {
		my $val = exists($params{$key}) ? $params{$key} : CONFIG_FIELDS->{$key};
		$val = int($val) if is_number_field($key);
		$rule{$key} = $val;
	}
	return %rule;
}

sub read_cfg
{
	my ($file, $sort_name) = @_;
	$file = DEFAULT_CONFIG unless defined $file;
	return () unless -e $file;
	my $cgf_text = do {
		local $/ = undef;
		open my $fh, "<", $file
			or die "could not open $file: $!";
		<$fh>;
	};
	my $result = from_json $cgf_text;

	if (defined($sort_name)) {
		if (is_number_field($sort_name)) {
			@$result = sort {$a->{$sort_name} <=> $b->{$sort_name}} @$result;
		}
		else {
			@$result = sort {$a->{$sort_name} cmp $b->{$sort_name}} @$result;
		}
	}
	return $result;
}

sub write_cfg
{
	my ($cfg, $file) = @_;
	$file = DEFAULT_CONFIG unless defined $file;
	open my $fh, ">", $file 
			or die "could not open $file: $!";
	print $fh to_json $cfg;
	close $fh;
}

sub rule_new_id
{
	return int(rand(4294967296));
}

sub config_demo
{
	return [
		{'id' => rule_new_id(),
			'priority' => 1,
			'src_dir' => 'DCIM',
			'src_ext' => 'jpg',
			'src_remove' => 0,
			'dest_folder'=>'photo',
			'dest_dir'=>'image/%Y-%m-%d',
			'dest_file'=>'',
			'dest_ext'=>'',
			'description' => 'Copy images'},
		{'id' => rule_new_id(),
			'priority' => 2,
			'src_dir' => 'MP_ROOT',
			'src_ext' => 'mpg',
			'src_remove' => 0,
			'dest_folder'=>'photo',
			'dest_dir'=>'video/%Y-%m-%d',
			'dest_file'=>'',
			'dest_ext'=>'',
			'description' => 'Copy videos'},
		{'id' => rule_new_id(),
			'priority' => 3,
			'src_dir' => '',
			'src_ext' => '3gp',
			'src_remove' => 0,
			'dest_folder'=>'photo',
			'dest_dir'=>'video/%Y-%m-%d',
			'dest_file'=>'',
			'dest_ext'=>'',
			'description' => 'Copy mobile videos'},
		{'id' => rule_new_id(),
			'priority' => 4,
			'src_dir' => '',
			'src_ext' => '',
			'src_remove' => 0,
			'dest_folder'=>'photo',
			'dest_dir'=>'other/%Y-%m-%d',
			'dest_file'=>'',
			'dest_ext'=>'',
			'description' => 'Copy others'}
	];
}

sub create_demo
{
	my $share = shift;
	$share = 'photo' unless defined $share;
	my $cfg = [
		{'id' => rule_new_id(),
			'priority' => 1,
			'src_dir' => 'DCIM',
			'src_ext' => 'jpg',
			'src_remove' => 0,
			'dest_folder' => $share,
			'dest_dir' => 'image/%Y-%m-%d',
			'dest_file' => '',
			'dest_ext' => '',
			'description' => 'Copy images'},
		{'id' => rule_new_id(),
			'priority' => 2,
			'src_dir' => 'MP_ROOT',
			'src_ext' => 'mpg',
			'src_remove' => 0,
			'dest_folder' => $share,
			'dest_dir' => 'video/%Y-%m-%d',
			'dest_file' => '',
			'dest_ext' => '',
			'description' => 'Copy videos'},
		{'id' => rule_new_id(),
			'priority' => 3,
			'src_dir' => '',
			'src_ext' => '3gp',
			'src_remove' => 0,
			'dest_folder' => $share,
			'dest_dir' => 'video/%Y-%m-%d',
			'dest_file' => '',
			'dest_ext' => '',
			'description' => 'Copy mobile videos'},
		{'id' => rule_new_id(),
			'priority' => 4,
			'src_dir' => '',
			'src_ext' => '',
			'src_remove' => 0,
			'dest_folder'=> $share,
			'dest_dir' => 'other/%Y-%m-%d',
			'dest_file' => '',
			'dest_ext' => '',
			'description' => 'Copy others'}
	];

	write_cfg($cfg, DEFAULT_CONFIG);
}
