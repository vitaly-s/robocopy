<?php

//defined('__CONFIG__') or define('__CONFIG__', '/etc/mia.conf');
defined('__CONFIG__') or define('__CONFIG__', '/var/packages/robocopy/etc/rules.conf');

function config_demo() {
	$demo[]= array('id' => mt_rand(),
		'priority' => 1,
		'src_dir' => 'DCIM',
		'src_ext' => 'jpg',
		'src_remove' => false,
		'dest_folder'=>'photo',
		'dest_dir'=>'image/%Y-%m-%d',
		'dest_file'=>'',
		'dest_ext'=>'',
		'description' => 'Copy images');
	$demo[]= array('id' => mt_rand(),
		'priority' => 2,
		'src_dir' => 'MP_ROOT',
		'src_ext' => 'mpg',
		'src_remove' => false,
		'dest_folder'=>'photo',
		'dest_dir'=>'video/%Y-%m-%d',
		'dest_file'=>'',
		'dest_ext'=>'',
		'description' => 'Copy videos');
	$demo[]= array('id' => mt_rand(),
		'priority' => 3,
		'src_dir' => '',
		'src_ext' => '3gp',
		'src_remove' => false,
		'dest_folder'=>'photo',
		'dest_dir'=>'video/%Y-%m-%d',
		'dest_file'=>'',
		'dest_ext'=>'',
		'description' => 'Copy mobile videos');
	$demo[]= array('id' => mt_rand(),
		'priority' => 4,
		'src_dir' => '',
		'src_ext' => '',
		'src_remove' => false,
		'dest_folder'=>'photo',
		'dest_dir'=>'other/%Y-%m-%d',
		'dest_file'=>'',
		'dest_ext'=>'',
		'description' => 'Copy others');

	return $demo;
}

// sort by priority
function cmp_by_priority($a, $b)
{
	$ap = (int)$a["priority"];
	$bp = (int)$b["priority"];
	if ($ap == $bp) return 0;
	if ($ap < $bp) return -1;
	return 1;
//	return strcmp($a["priority"], $b["priority"]);
}

function config_read($sorted) {
	$result = json_decode(file_get_contents(__CONFIG__), true);
	if ($sorted === true) {
		usort($result, 'cmp_by_priority');
	}
	return $result;
}

function config_write($data) {
	$text = json_encode($data);
	return @file_put_contents(__CONFIG__, $text);
//	$f = fopen(__CONFIG__, 'w');
//	if (!$f) {
//		return false;
//	} else {
//		$bytes = fwrite($f, $text);
//		fclose($f);
//		return $bytes;
//	}
}

?>
