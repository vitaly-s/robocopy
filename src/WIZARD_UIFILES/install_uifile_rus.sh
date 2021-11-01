#!/bin/sh

/bin/cat > $SYNOPKG_TEMP_LOGFILE <<'EOF'
[{
	"step_title": "Демо конфигурация",
	"items": [{
		"type": "multiselect",
		"_desc": "Демо конфигурация",
		"subitems": [{
			"key": "PKGWIZARD_CREATE_DEMO",
			"desc": "Создать демо конфигурацию",
			"validator": {
				"fn": "{console.log(arguments);return true;}"
			}
		}]
	}, {
		"type": "combobox",
		"desc": "Выберите общую папку для использования в демо правилах",
		"subitems": [{
			"defaultValue": "photo",
			"key": "PKGWIZARD_SHARE",
			"desc": "Общая папка",
			"displayField": "name",
			"valueField": "name",
			"editable": false,
			"mode": "remote",
			"api_store": {
				"api": "SYNO.Core.Share",
				"method": "list",
				"version": 1,
				"root": "shares",
				"idProperty": "name",
				"fields": ["name", "desc"]
			},
			"validator": {
				"fn": "{console.log(arguments);return true;}"
			}
		}]
	}]
}]
EOF

exit 0
