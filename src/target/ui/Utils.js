/* Copyright (c) 2013-2021 Vitaly Shpachenko. All rights reserved. */

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.PIC_PREFIX = "/webman/3rdparty/robocopy/images/";
SYNO.SDS.RoboCopy.CGI = "/webman/3rdparty/robocopy/robocopy.cgi";
SYNO.SDS.RoboCopy.AppName = "SYNO.SDS.RoboCopy.Instance";

_RC_STR = function(b, a) {
    return _TT(SYNO.SDS.RoboCopy.AppName, b, a)
};

_DEBUG = function(...args){
    if(typeof(console) !== 'undefined') {
        console.log(...args);
    }
};
_TRACE = function(){
    if(typeof(console) !== 'undefined') {
        console.trace();
    }
};

//function log() {
//    if(typeof(console) !== 'undefined') {
//        console.log.apply(console, arguments);
//    }
//}

var getXType = function() {
    for (var i = 0; i < arguments.length; i++) {
        if (Ext.ComponentMgr.isRegistered(arguments[i])) {
            return arguments[i];
        }
    }
    return undefined;
};

_XType_TabPanel = getXType("syno_tabpanel", "tabpanel");
_XType_FormPanel = getXType("syno_formpanel" ,"form");
_XType_FieldSet = getXType("syno_fieldset", "fieldset");
_XType_Radio = getXType("syno_radio", "radio");
_XType_RadioGroup = getXType("syno_radiogroup", "radiogroup");
_XType_DisplayField = getXType("syno_displayfield", "displayfield");
_XType_CheckBox = getXType("syno_checkbox", "checkbox");
_XType_NumberField = getXType("syno_numberfield", "numberfield");
_XType_ComboBox = getXType("syno_combobox", "combo");
_XType_TextField = getXType("syno_textfield", "textfield");
_XType_Paging = getXType("syno_paging", "paging");
_XType_GridPanel = getXType("syno_gridpanel", "grid");
_XType_DateField = getXType("syno_datefield", "datefield");

isDsmV4 = function() {
//    var version = parseInt(_S("version"), 10);
    var version = _S("version");
    return ((2198 <= version) && (version <= 4244));
//    if ((2198 <= version) && (version <= 4244)) {
//        return true;
//    }
//        var majorversion = _S("majorversion");
//    return false;
};

isDsmV7 = function() {
//    var version = parseInt(_S("version"), 10);
    return (_S("version") >= 40000);
};

SYNO.SDS.RoboCopy.GetErrorMessage = function (result, fldSection="ui") {
    if (result && result.key) {
        switch(result.key) {
//            case 'config_write_error':
//                return _RC_STR("error", "config_write_error");
//            case 'invalid_id':
//                return _RC_STR("error", "invalid_id");
            case 'not_found': //result.value
                return _RC_STR("error", "not_found"); 
            case 'not_run': //result.value
                return _RC_STR("error", "system_error"); 
            case 'invalid_params': //result.name, result.value, result.details
                var name = "",
                    value = "";
                if (result.name && result.name !== "") {
                    name = _RC_STR(fldSection, result.name);
                }
                if (name === "") {
                    return _T("error", "error_unknown");
                }
                if (result.value && result.value !== "") {
                    value = result.value;
                    if (result.details && Ext.isArray(result.details)) {
                        result.details.sort((a,b) => (a.pos < b.pos) ? 1 : ((b.pos < a.pos) ? -1 : 0));
                        for (var i = 0; i < result.details.length; i++) {
                            var pos = -1,
                                len = 0;
                            if (result.details[i].pos) {
                                pos = result.details[i].pos-1;
                            }
                            if (result.details[i].text) {
                                len = result.details[i].text.length;
                            }
                            if ((pos != -1) && (len > 0)) {
                                value = value.substr(0, pos) 
                                    + '<font color="red"><u><b>' + value.substr(pos, len) + '</b></u></font>'
                                    + value.substr(pos + len);
                            }
                        }
                    }
                }
//                _DEBUG("Error value: " + value);
                if (value === "") {
                    return String.format(_RC_STR("error", "bad_field"), name);
                }
                return String.format(_RC_STR("error", "bad_field_value"), name, value);
            case 'process_file':
                if (result.name && result.name !== "") {
                    return String.format(_RC_STR("error", "prosess_file_name"), result.name);
                }
                return _RC_STR("error", "prosess_file");
            case 'permission_read':
                return String.format(_RC_STR("error", "permission_read"), result.path);
            case 'permission_write':
                return String.format(_RC_STR("error", "permission_write"), result.path);
//            default:
//                return _T("error", "error_unknown");
        }
//        var msg = _RC_STR(result.sec, result.key);
//        if (!msg || msg === "")
//            return result.sec + ":" + result.key; 
        return _RC_STR("error", "system_error");
//        return _T("error", "error_unknown");
//        return msg;
    }
    return "";
};

Ext.ns("SYNO.SDS.RoboCopy.utils");
Ext.apply(SYNO.SDS.RoboCopy.utils, {
    parseFullPathToFileName: function(file, path_delim) {
        var d = path_delim ? path_delim : "/";
        var result = "";
        var idx = file.lastIndexOf(d);
        if (-1 == idx) {
            idx = file.lastIndexOf(d === "\\" ? "/" : "\\")
        }
        result = file.substring(idx + 1);
        return result;
    },
    ParseArrToFileName: function(files, path_delim) {
        var d = path_delim ? path_delim : "/";
        var f = [];
        for (i = 0; i < files.length; i++) {
            f.push(SYNO.SDS.RoboCopy.utils.parseFullPathToFileName(files[i], d))
        }
        return f.join(", ");
    },
    checkFn0: function(a, c) {
        //["file_id", "filename", "filesize", "mt", "ct", "at", "privilege_str", "privilege", "owner", "group", "icon", "type", "path", "isdir", "uid", "gid", "is_compressed"]),
        if (1 !== c.length || !c[0].get("isdir")) {
            return false;
        }
        var apps = SYNO.SDS.AppMgr.getByAppName(SYNO.SDS.RoboCopy.AppName);
        if (!apps || 0 === apps.length) {
            return true;
        }
        var mb = apps[0].window.getMsgBox(); //.getDialog();
        return !mb || !mb.isVisible();
//        return true;
    },
    filterSelection: function(selected, dir_val) {
        //["file_id", "filename", "filesize", "mt", "ct", "at", "privilege_str", "privilege", "owner", "group", "icon", "type", "path", "isdir", "uid", "gid", "is_compressed"]),
        var result = [];
        if (Ext.isArray(selected)) {
            Ext.each(selected, function(f, idx) {
                var isdir = f.get("isdir");
                if (isdir !== dir_val) {
                    return;
                }
                var real_path = f.get("real_path") || f.get("path");
                if (!real_path || (-1 != result.indexOf(real_path))) {
                    return
                }
                result.push(real_path)
            }, this);
        }
        return result;
    },
    checkSingleton: function() {
        var apps = SYNO.SDS.AppMgr.getByAppName(SYNO.SDS.RoboCopy.AppName);
        if (!apps || 0 === apps.length) {
            return true;
        }
        var mb = apps[0].window.getMsgBox(); //.getDialog();
        return !mb || !mb.isVisible();
    },
    checkFn: function(a, c) {
//        _DEBUG("checkFn", a, c);
        if (!_S("is_admin")) {
            return false
        }
        var selected = SYNO.SDS.RoboCopy.utils.filterSelection(c, true);
        return (selected.length > 0) && SYNO.SDS.RoboCopy.utils.checkSingleton();
    },
    launchFn: function(b) {
        var selected = SYNO.SDS.RoboCopy.utils.filterSelection(b, true);
        if (selected.length > 0) {
            SYNO.SDS.AppLaunch(SYNO.SDS.RoboCopy.AppName, 
                {
                    folders: selected
                }, 
                false);
        }
    },
    launchFnMove: function(b) {
        var selected = SYNO.SDS.RoboCopy.utils.filterSelection(b, true);
        if (selected.length > 0) {
            SYNO.SDS.AppLaunch(SYNO.SDS.RoboCopy.AppName, 
                {
                    folders: selected,
                    src_remove: 1
                }, 
                false);
        }
    },
    launchFnCopy: function(b) {
//        _DEBUG("launchFnCopy", b);
        var selected = SYNO.SDS.RoboCopy.utils.filterSelection(b, true);
        if (selected.length > 0) {
            SYNO.SDS.AppLaunch(SYNO.SDS.RoboCopy.AppName, 
                {
                    folders: selected,
                    src_remove: 0
                }, 
                false);
        }
    // },
    // launchEditor: function(b) {
        // var selected = SYNO.SDS.RoboCopy.utils.filterSelection(b, true);
        // if ((selected.length == 1) && (selected[0].substring(selected[0].lastIndexOf(".") + 1) === "jpg")) {
            // SYNO.SDS.AppLaunch(SYNO.SDS.RoboCopy.AppName, 
                // {
                    // folders: selected,
                    // src_remove: 0
                // }, 
                // false);
        // }
    }
});

