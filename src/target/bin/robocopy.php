#!/usr/bin/php -d safe_mode_exec_dir=""
<?php


function argvStr($arg_list, $onlyArgs = FALSE) {
	if ($onlyArgs) {
		array_shift($arg_list);
	}
	$arg_list = array_map('escapeshellarg', $arg_list);
	return implode(' ', $arg_list);
}

// Run same self with valid permissions
if ((ini_get('open_basedir') != "") || (ini_get('safe_mode_exec_dir') != "")) {
	$cmd = '/usr/bin/php -d open_basedir="" -d safe_mode_exec_dir="" ' . argvStr($argv);
	system($cmd, $result);
	exit($result);
}

require_once(__DIR__.'/config.php'); 

define('__SYNOINFO__', '/etc/synoinfo.conf');
define('__DEF_SYNOINFO__', '/etc.defaults/synoinfo.conf');
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
function outTTYS1($data){
	$dh = @fopen('/dev/ttyS1', 'r+b');
	if ($dh !== FALSE)
	{
		@fwrite($dh, $data);
		@fclose($dh);
	}
}
	
function syno_beep() {
	outTTYS1("2");
}

function syno_longbeep() {
	outTTYS1("3");
}

function syno_copyled_off() {
	outTTYS1("B");
}

function syno_copyled_on() {
	outTTYS1("@");
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
	exec('/usr/syno/bin/synologset1 sys ' . $type . ' 0x11800000 ' . escapeshellarg('RoboCopy: ' . $str));
	exec('/usr/syno/bin/synologset1 copy ' . $type . ' 0x11800000 ' . escapeshellarg('RoboCopy: ' . $str));
//	print(strtoupper($type) . " : " . $str . ".\n");
}

//http://forum.synology.com/enu/viewtopic.php?f=27&t=55627
function syno_notify($title, $message, $to = '@administrators') {
	exec('/usr/syno/bin/synodsmnotify ' . $to . ' ' . escapeshellarg($title) . ' ' . escapeshellarg($message));
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
/*
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
*/

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

function syno_copy_folders() {
	$result = array();
	$synoinfo = @parse_ini_file(__SYNOINFO__);
	if ($synoinfo !== FALSE) {
		foreach (array('usbcopyfolder'=>'USBCopy*' , 'sdcopyfolder'=>'SDCopy*') as $name => $mask) {
			$folder = $synoinfo[$name];
			if ($folder != '') {
				$folder_path = get_share_path($folder);
				if ($folder_path !== FALSE) {
					$result[$name] = $folder_path . '/' . $mask;
				}
				else {
					syno_log('warn', "Can not get [$name] path");
				}
			}
		}
	}
	return $result;
}

///////////////////////////////////////////////////
if (basename($argv[0]) === 'synousbcopy') {

	$dir_list = array();

	$copy_dirs = syno_copy_folders();
	foreach ($copy_dirs as $key => $mask) {
		$list = glob($mask, GLOB_ONLYDIR);
		if ($list !== FALSE) {
			$dir_list[$key] = $list;
		}
	}

	// Run original SynoUsbCopy
	if (defined('__USBCOPYBIN__')) {
		exec(__USBCOPYBIN__ . ' ' .  argvStr($argv, TRUE), $out, $result);

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

	$dirs = array();
	foreach ($copy_dirs as $key => $mask) {
		$list = glob($mask, GLOB_ONLYDIR);
		if ($list !== FALSE) {
			$dirs = array_merge($dirs, array_diff($list, $dir_list[$key]));
		}
	}
	if (count($dirs) == 0) {
		exit(0);
	}
}
else {
	// Run with parameters
	if ($argc == 1) {
		echo "Usage:\n\t" . basename($argv[0]) . " src_dir1 [src_dir1...]\n";
		exit(1);
	}
	$dirs = $argv;
	array_shift($dirs);
}

syno_beep();

$cfg = config_read(true);

foreach ($dirs as $dir) {
	syno_log('info', 'Started processing [' . basename($dir) . ']');
	foreach ($cfg as $line) {
		process_php($dir, $line);
	}
	syno_log('info', 'Finished processing [' . basename($dir) . ']');
}

syno_notify('RoboCopy', 'Processing has been completed.');

syno_longbeep();

?>