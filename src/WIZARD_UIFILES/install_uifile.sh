#!/bin/sh

/bin/cat > $SYNOPKG_TEMP_LOGFILE <<'EOF'
[{
	"step_title": "Demo configuration",
	"items": [{
		"type": "multiselect",
		"_desc": "Demo configuration",
		"subitems": [{
			"key": "PKGWIZARD_CREATE_DEMO",
			"desc": "Create demo configuration",
			"validator": {
				"fn": "{console.log(arguments);return true;}"
			}
		}]
	}, {
		"type": "combobox",
		"desc": "Select shared folder for uses in demo rules",
		"subitems": [{
			"defaultValue": "photo",
			"key": "PKGWIZARD_SHARE",
			"desc": "Shared folder",
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
