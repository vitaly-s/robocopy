#!/usr/bin/php
<?php

define('__USBCOPYBIN__', '/usr/syno/bin/synousbcopy_bin');

// Run same self with valid permissions
if ((ini_get('open_basedir') != "") || (ini_get('safe_mode_exec_dir') != "")) {
	$cmd = '/usr/syno/bin/php -d open_basedir="" -d safe_mode_exec_dir="" "' . implode('" "', $argv) . '"';
	system($cmd, $result);
	exit($result);
}

function syno_sys_log($type, $str) {
	exec('/usr/syno/bin/synologset1 sys ' . $type . ' 0x11800000 "' . $str . '"');
}

syno_sys_log('info', 'Run: ' . implode(' ', $argv));

if (basename($argv[0]) === 'synousbcopy') {
	// Run original SynoUsbCopy
	if (defined('__USBCOPYBIN__')) {
		$arg_str = '';
		if ($argc > 1) {
			$arg_arr = $argv;
			array_shift($arg_arr);
			$arg_str = ' ' . implode('" "', $arg_arr);
		}
		exec(__USBCOPYBIN__ . $arg_str, $out, $result);
		exit($result);
	}
}

print_r($argv);

?>
