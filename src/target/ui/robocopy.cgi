#!/usr/bin/php -d open_basedir=""
<?php

/*
if ((ini_get('open_basedir') != "") || (ini_get('safe_mode_exec_dir') != "")) {
	$cmd = '/usr/syno/bin/php -d open_basedir="" -d safe_mode_exec_dir="" ' . $_SERVER['PHP_SELF'];
	system($cmd, $result);
	exit($result);
}
*/

require_once(__DIR__ . '/../bin/config.php'); 
require_once(__DIR__ . '/../bin/cgi.php');

function get_share_list() {
	exec('/usr/syno/bin/synoshare --enum local', $list);
	unset($list[0]);
	unset($list[1]);
	$result = array();
	foreach ($list as $name) {
		exec('/usr/syno/bin/synoshare --get ' . $name, $out);
		$pattern = '/Comment.*\[(.*)\]/';
		$comment = '';
		foreach ($out as $line){
			if (preg_match($pattern, $line, $matches) === 1) {
				$comment = $matches[1];
			}
		}
		$result[] = array('name' => $name, 'comment' => $comment);
	}
	return $result;
}

function response_list($list) {
	return array('data'=>$list, 'total'=>count($list));
}

function response_success($data) {
	return array('data'=>$data, 'success'=>true);
}
//{
//   "errinfo" : {
//      "key" : "nonexist",
//      "line" : 109,
//      "sec" : "error"
//   },
//   "success" : false
//}
function response_error($key) {
	return array('errorinfo'=>array('key'=>$key, 'sec'=>'error'), 'success'=>false);
}

function parse_item($params) {
	return array('id' => $params['id'],
		'priority' => (int)$params['priority'],
		'src_dir' => $params['src_dir'],
		'src_ext' => $params['src_ext'],
		'dest_folder' => $params['dest_folder'],
		'dest_dir' => $params['dest_dir'],
		'dest_file' => $params['dest_file'],
		'dest_ext' => $params['dest_ext'],
		'description' => $params['description'],
		'src_remove' => (bool)$params['src_remove']
	);
}

/////
function action_list($params) {
	$cfg = config_read();
	if (!isset($params['start'])) $params['start'] = 0;
	if (!isset($params['limit'])) $params['limit'] = count($cfg);
	$i = 0;
	//foreach ()
 
	return response_list($cfg);
}

function action_shared($params) {
	$list = get_share_list();

	return response_list($list);
}

function action_add($params) {
	$result = parse_item($params);
	$result['id'] = mt_rand();

	$cfg = config_read();
	$cfg[]= $result;

	if (config_write($cfg) === false) {
		return response_error('config_write_error');
	}
	return response_success($result);
}

function action_edit($params) {
	$result = parse_item($params);
	if (!isset($result['id'])) {
		return response_error('invalid_id');
	}
	$cfg = config_read();
	foreach($cfg as $key => $item) {
		if ($item['id'] == $result['id'] ) {
			$cfg[$key] = $result;
			if (config_write($cfg) === false) {
				return response_error('config_write_error');
			}
			return response_success(NULL);
		}
	}
	return response_error('not_found');
}

function action_remove($params) {
	if (!isset($params['id'])) {
		return response_error('invalid_id');
	}
	$cfg = config_read();
	foreach($cfg as $key => $item) {
		if ($item['id'] == $params['id'] ) {
			$result = $cfg[$key];
			unset($cfg[$key]);
			$cfg = array_values($cfg);
			if (config_write($cfg) === false) {
				return response_error('config_write_error');
			}
			return response_success($result);
		}
	}
	return response_error('not_found');
}

function action_demo($params) {
	$demo = config_demo();
	print("2\n");
	if (config_write($demo) === false) {
		return response_error('config_write_error');
	}
	return $demo;
}

?>
