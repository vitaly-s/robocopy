#!/usr/bin/php
<?php

// Run same self with valid permissions
if ((ini_get('open_basedir') != "") || (ini_get('safe_mode_exec_dir') != "")) {
	$cmd = '/usr/syno/bin/php -d open_basedir="" -d safe_mode_exec_dir="" "' . implode('" "', $argv) . '"';
	system($cmd, $result);
	exit($result);
}

require_once(__DIR__.'/config.php'); 

define('__SYNOINFO__', '/etc/synoinfo.conf');
define('__DEF_SYNOINFO__', '/etc.defaults/synoinfo.conf');
define('__USBCOPYDIR__', 'USBCopy_');
define('__USBCOPYBIN__', '/usr/syno/bin/synousbcopy_bin');

// /etc/synoinfo.conf "language"

function get_share_info($name) {
	exec('/usr/syno/bin/synoshare --get ' . $name, $out, $result);
	$pattern = '/(\w+)\s(\w+)?.*\[(.*)\]/';
	$result = array();
	foreach ($out as $line){
		if (preg_match($pattern, $line, $matches) === 1) {
			$key = $matches[1];
			$value = $matches[3];
			if ($matches[2] === 'list') {
				$key .= ' list';
				if ($value == '') {
					$value = array();
				}
				else {
					$value = explode(',', $value);
				}
			}
			$result[$key] = $value;
		}
	}
	return $result;
}

function get_share_path($name) {
	exec('/usr/syno/bin/synoshare --get ' . $name, $out);
	$pattern = '/Path.*\[(.*)\]/';
	$comment = '';
	foreach ($out as $line){
		if (preg_match($pattern, $line, $matches) === 1) {
			return $matches[1];
		}
	}
	return FALSE;
}


//see http://oinkzwurgl.org/?action=browse;oldid=ds106series;id=diskstation_ds106series
function syno_beep() {
	system("echo 2 > /dev/ttyS1");
}

function syno_longbeep() {
	exec("echo 3 > /dev/ttyS1");
}

function syno_copyled_off() {
	exec("echo B > /dev/ttyS1");
}

function syno_copyled_on() {
	exec("echo @ > /dev/ttyS1");
}

function syno_copyled_blink() {
	exec("echo A > /dev/ttyS1");
}

//Write to system log http://forum.synology.com/enu/viewtopic.php?p=70228
//1. edit /usr/syno/synosdk/texts/enu/events and add this string:
//
//# vi /usr/syno/synosdk/texts/enu/events
//
//[90000000]
//90000001 = "This is my log."
//
//2. run syslogset1 to set log:
//
//# synologset1 sys info 0x90000001
//
//11800000	="@1."

//[12600000]
//12600001="@1 failed."
//1260000B="The local disk is insufficient to copy file [@1]."
//1260000C="Program stopped while copying file [@1]."
//12600011="Unexpected error occurred while proceeding [@1]."
//12600014="@1 started."
//12600015="@1 finished."
//12600016="User cancelled the copy."
//1260001A="Failed to copy because local disk is insufficient."
//1260001B="Failed to copy because @1 volume is not mounted."
//1260001C="Failed to copy because @1 is initializing."
//1260001F="Failed to copy because @1 is disconnected."
//12600021="USB Copy destination folder was set to [@1]."
//12610021="SD Copy destination folder was set to [@1]."


//USAGE : synologset1 [sys | man | conn](copy netbkp)   [info | warn | err] eventID(%X) [substitution strings...]
function syno_log($type, $str) {
	exec('/usr/syno/bin/synologset1 sys ' . $type . ' 0x11800000 "RoboCopy: ' . $str . '"');
//	print(strtoupper($type) . " : " . $str . ".\n");
}

//http://forum.synology.com/enu/viewtopic.php?f=27&t=55627
function syno_notify($title, $message, $to = '@administrators') {
	exec('/usr/syno/bin/synodsmnotify ' . $to . ' "' . $title . '" "' . $message . '"');
}


function supported_usbcopy() {
	$def_synoinfo = parse_ini_file(__DEF_SYNOINFO__);
	return ($def_synoinfo['usbcopy'] === 'yes');
}

function syno_usbcopy_folder() {
	$synoinfo = @parse_ini_file(__SYNOINFO__);

	if ($synoinfo === FALSE) {
		return FALSE;
	}
	if ($synoinfo['usbcopyfolder'] != '') {
		return $synoinfo['usbcopyfolder'];
	}
	return FALSE;
}

function file_original_time($file) {
	$exif = @exif_read_data($file, 'IFD0', 0);
	if ($exif !== false) {
		if (@array_key_exists('DateTimeOriginal', $exif)) {
			return strtotime($exif['DateTimeOriginal']);
		}
		if (@array_key_exists('DateTime', $exif)) {
			return strtotime($exif['DateTime']);
		}
		if (@array_key_exists('DateTimeDigitized', $exif)) {
			return strtotime($exif['DateTimeDigitized']);
		}
	}
	//run 'exiftool -DateTimeOriginal -j ' . $file
	return filemtime($file);
}

// returns TRUE if files are the same, FALSE otherwise
function files_identical_0($fn1, $fn2) {
    if(filetype($fn1) !== filetype($fn2))
        return FALSE;

    if(filesize($fn1) !== filesize($fn2))
        return FALSE;

    if(!$fp1 = fopen($fn1, 'rb'))
        return FALSE;

    if(!$fp2 = fopen($fn2, 'rb')) {
        fclose($fp1);
        return FALSE;
    }

    $same = TRUE;
    while (!feof($fp1) and !feof($fp2))
        if(fread($fp1, READ_LEN) !== fread($fp2, READ_LEN)) {
            $same = FALSE;
            break;
        }

    if(feof($fp1) !== feof($fp2))
        $same = FALSE;

    fclose($fp1);
    fclose($fp2);

    return $same;
}

function files_identical($fn1, $fn2) {
	return ((filesize($fn1) === filesize($fn2)) 
			&& (md5_file($fn1) === md5_file($fn2)));
}

function process_path($src_base, $src, $src_remove, $dest_fmt, $src_ext) {
//	echo 'process_path(' . $src_base . ', ' . $src . ', ' . $src_remove . ', ' . $dest_fmt . ', ' . $src_ext . ")\n";
	if (is_dir($src)) {
		foreach (scandir($src) as $item) {
			if (($item == '.') || ($item == '..')) continue;
			process_path($src_base, $src . '/' . $item, $src_remove, $dest_fmt, $src_ext);
		}
		if ($src_remove) {
//			echo 'rmdir ' . ($src) . "\n";
			@rmdir($src);
		}
	}
	else
	{
		$pathinfo = pathinfo($src);
		if (($src_ext == '') || (strtolower($pathinfo['extension']) == $src_ext)) 
		{
			$dir = str_replace($src_base , '', $pathinfo['dirname']);
			$dir = trim($dir, '/');
			$file_time = file_original_time($src);
			$dest_file = strftime($dest_fmt, $file_time);
			$dest_file = str_replace("%d", $dir, $dest_file);
			$dest_file = str_replace("%f", $pathinfo['filename'], $dest_file);
			$dest_file = str_replace("%e", $pathinfo['extension'], $dest_file);
			$dest_file = str_replace('//', '/', $dest_file);
			$dest_dir = dirname($dest_file);
			if (!is_dir($dest_dir)) {
				if (is_file($dest_dir)) {
//					echo 'Delete file: ' . $dest_dir . "\n";
					unlink($dest_dir);
				}
//				echo 'Create dir: ' . $dest_dir . "\n";
				mkdir($dest_dir, 0777, true);
			}
			if (is_dir($dest_file)) {
				syno_log('warn', 'Cannot overwrite directory ' . $dest_file);
				return;
			}
			if (is_file($dest_file)) {
				if (!files_identical($src, $dest_file)) {
					syno_log('warn', 'Cannot overwrite file ' . $dest_file . ', because it not identical to ' . $src);
					return;
				}
				if ($src_remove) {
					unlink($src);
				}
				return;
			}
//			echo 'f: ' . $src . '->' . $dest_file . "\n";
			if ($src_remove) {
//				echo 'fm: ' . $src . '->' . $dest_file . "\n";
				rename($src, $dest_file);
			}
			else {
//				echo 'fc: ' . $src . '->' . $dest_file . "\n";
				if (copy($src, $dest_file)) {
					touch($dest_file, $file_time);
				}
			}
		}
//		else{
//			echo 'skip: ' . $src . ' != ' . $ext . "\n";
//		}
	}
}

function process_php($src_path, $item) {
	$src_dir = $src_path . ($item['src_dir'] != '' ? '/' . $item['src_dir'] : '');
	if (!is_dir($src_dir)) {
//		echo "\t\t" . $src_dir . " not exists\n";
		return TRUE;
	}

	$dest_path = get_share_path($item['dest_folder']);
	if ($dest_path === false)
	{
		syno_log('err', "Invalid destination share name: " . $item['dest_folder']);
		return FALSE;
	}
	$dest_path .= '/' . ($item['dest_dir'] != '' ? $item['dest_dir'] : '%%d');
	$dest_path .= '/' . ($item['dest_file'] != "" ? $item['dest_file'] : '%%f');
	$dest_path .= '.' . ($item['dest_ext'] != "" ? $item['dest_ext'] : '%%e');

	$src_remove = ($item['src_remove'] == true ? true : false);
//	echo $src_dir . ' -> ' . $dest_path . ' - ' . strftime($dest_path). "\n";
	process_path($src_dir, $src_dir, $src_remove, $dest_path, strtolower($item['src_ext']));
//	if ($item['src_ext'] != '') {
//		$cmd .= ' -ext ' . $item['src_ext'];
//	}
	

	return TRUE;
}

///////////////////////////////////////////////////
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

//		print("Out:\n");
//		var_dump($out);
//		print("\n\nResult:\n");
//		var_dump($result);
//		return;
		if (count($out) > 0) {
			echo implode("\n", $out) . "\n";
			exit($result);
		}
	}

	// Get usbcopy folders
	$src_folder = syno_usbcopy_folder();
	if ($src_folder === FALSE) {
		syno_log('err', "Can not get usbcopy folder");
		exit(1);
	}

	$src_path = get_share_path($src_folder);
	if ($src_path === FALSE) {
		syno_log('err', "Can not get usbcopy path");
		exit(1);
	}

	$dirs = glob($src_path . '/' . __USBCOPYDIR__ . '*');
	rsort($dirs);
	
	$dirs = array(array_shift($dirs));
}
else {
	// Run with parameters
	if ($argc == 1) {
		echo "Usage: " . basename($argv[0]) . " src_dir1 [src_dir1...]\n";
		exit(1);
	}
	$dirs = $argv;
	array_shift($dirs);
}


$cfg = config_read(true);

//syno_copyled_blink();
syno_beep();

foreach ($dirs as $dir) {
	syno_log('info', 'Start import from "' . $dir . '"');
	foreach ($cfg as $line) {
		process_php($dir, $line);
	}
	syno_log('info', 'Finished import from "' . $dir . '"');
	syno_notify('RoboCopy', 'Finished import from "' . $dir . '"');
}

//syno_copyled_off();
syno_longbeep();

?>