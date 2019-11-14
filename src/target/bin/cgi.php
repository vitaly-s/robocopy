<?php

function call_action($action, $params) {
//	$action = 'action_' . $params['action'];
	if (function_exists($action)) {
//		print("Content-type: text/plain; charset=UTF-8\n\n");
//		print($action . "\n\n");
		print("Content-type: application/json; charset=UTF-8\n\n");
		print(json_encode($action($params)));
		return TRUE;
	}
	return FALSE;
}

defined('__ACTION_POST__') or define('__ACTION_POST__', 'action_');
defined('__ACTION_GET__') or define('__ACTION_GET__', 'action_');

if (isset($_SERVER['REQUEST_METHOD'])) {
	if ($_SERVER['REQUEST_METHOD'] === 'POST') {
		parse_str(file_get_contents('php://stdin'), $_POST);
		unset($_GET);
		if (call_action(__ACTION_POST__ . $_POST['action'], $_POST)) {
			exit(0);
		}
	}
	elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
		parse_str($_SERVER["QUERY_STRING"], $_GET);
		unset($_POST);
//		$_POST = $_GET;
		if (call_action(__ACTION_GET__ . $_GET['action'], $_GET)) {
			exit(0);
		}
	}
	exit(404);
}

print("HTTP/1.0 403 Forbidden\n");
exit(404);
//return;

?>
