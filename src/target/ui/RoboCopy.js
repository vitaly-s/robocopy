/* Copyright (c) 2013-2021 Vitaly Shpachenko. All rights reserved. */

/*
    onChooseDest: function() {
        if (!this.TreeDialog || this.TreeDialog.isDestroyed) {
            this.TreeDialog = new SYNO.FileStation.TreeDialog({
                RELURL: this.RELURL,
                blDynamicForm: false,
                owner: this,
                webfm: this.webfm
            });
            this.TreeDialog.mon(this.TreeDialog, "beforesubmit", this.onCheckDestPrivilege, this);
            this.TreeDialog.mon(this.TreeDialog, "callback", this.onTreeDialogHide, this)
        }
        var a = this.TreeDialog;
        a.load(_WFT("filetable", "filetable_extract"), false, this.gUID, this.gGID)
    },
    onCheckDestPrivilege: function(a) {
        var b = this.TreeDialog;
        if (b) {
            if (_S("is_admin") === true || _S("domainUser") == "true") {
                return true
            }
            if (!SYNO.webfm.utils.checkShareRight(a.shareRight, SYNO.webfm.utils.RW)) {
                b.getMsgBox().alert(_WFT("filetable", "filetable_extract"), _WFT("error", "error_privilege_not_enough"));
                return false
            }
            if (Ext.isDefined(a.folderRight)) {
                var c = {
                    right: a.folderRight,
                    needRight: SYNO.webfm.utils.ReqPrivilege.DestFolder.Extract
                };
                if (!SYNO.webfm.utils.checkFileRight(c)) {
                    b.getMsgBox().alert(_WFT("filetable", "filetable_extract"), _WFT("error", "error_privilege_not_enough"));
                    return false
                }
            }
            return true
        }
    },
    onTreeDialogHide: function() {
        var a = this.TreeDialog;
        if (!a) {
            return
        }
        var b = a.getParameters();
        if (b.fdrName) {
            this.UpdateTargetPath(b.fdrName)
        }
    },

*/


Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.Action = Ext.extend(Ext.Component, {
    simpleProgress: isDsmV4(),
    constructor: function (config, bkTask) {
        this.initVaribles(config);
        var taskid = bkTask ? bkTask.id : config.bkTaskCfg.taskid;
        if (!bkTask) {
            bkTask = SYNO.SDS.BackgroundTaskMgr.addTask({
                id: taskid,
                title: this.genBkTitle(this.actionStr, this.fileStr),
                query: {
                    url: config.bkTaskCfg.url,
                    params: {
                        action: "task_progress",
                        taskid: taskid
                    }
                },
                cancel: {
                    url: config.bkTaskCfg.url,
                    params: {
                        action: "task_cancel",
                        taskid: taskid
                    }
                },
                options: config.actionCfg
            })
        }
        bkTask.addCallback(this.onTaskCallBack, this);
        if (!this.blMsgMinimized && !this.isOwnerDestroyed()) {
            var e = ((config.msgCfg.msg) ? config.msgCfg.msg : this.actingText) + "...";
            var d = (!(config.msgCfg.minimizable === false));
            this.showProgress(this.actionText, e, this.onCancelCallBack.createDelegate(this, [bkTask]), false, config.msgCfg.progress)
        }
        this.bkTask = bkTask;
    },
    initVaribles: function (cfg) {
        Ext.apply(this, cfg.actionCfg || {});
//        this.webfm = cfg.webfm;
        this.owner = cfg.owner || this.webfm.owner;
        this.blMsgMinimized = (this.blMsgMinimized === true) ? true : ((cfg.msgCfg && cfg.msgCfg.blMsgMinimized) ? cfg.msgCfg.blMsgMinimized : false);
//        this.actionStr = cfg.actionStr;
//        this.actingStr = cfg.actingStr;
        this.actionText = _RC_STR("app", "app_name");
//        this.actingText = "actingText"; //SYNO.webfm.utils.getLangText(this.actingStr)
    },
    genBkTitle: function (a, b) {
        return ["{0}: {1}", _RC_STR("app", "app_name"), b];
    },
    onCancelCallBack: function (a) {
        a.cancel()
    },
    onCancelTask: function (c) {
        this.hideProgress();
        if (c.errno && c.errno.section && c.errno.key) {
//            var a = c.errno;
//            var b = _WFT(a.section, a.key);
//            this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.GetErrorMessage(response));
//            if (this.isOwnerDestroyed() || !this.isOwnerVisible()) {
//                SYNO.SDS.SystemTray.notifyMsg("SYNO.SDS.App.FileStation3.Instance", this.actionText, b)
//            } else {
//                this.getMsgBox().alert(this.actionText, b)
//            }
        }
    },
    onFinishTask: function (a, b) {
        _DEBUG("RoboCopy.Action.onFinishTask");
        if ((b.result && b.result == "fail") || a === -1) {
            this.showErrItems(b);
        } else {
            this.onCompleteTask(b);
        }
    },
    onCompleteTask: function (a) {
        _DEBUG("RoboCopy.Action.onCompleteTask");
        this.hideProgress();
//        this.refreshTreeNode(this.srcIdArr, this.destId, "move" == this.action && a.bldir);
//        if (Ext.isDefined(a.sdbid) && Ext.isDefined(a.sdbvol)) {
//            this.refreshSearhGrid(a.sdbid, a.sdbvol)
//        }
    },
    onProgressTask: function (progress, data) {
        _DEBUG("RoboCopy.Action.onProgressTask");
        if (this.blMsgMinimized || this.isOwnerDestroyed()) {
            return;
        }
        if (progress && data.pfile && 0 < progress) {
            var percentText = (progress * 100).toFixed(2) + "&#37;";
            var progressText = "";
            if (Ext.isNumber(data.total_size) && (0 < data.total_size)) {
                progressText = Ext.util.Format.fileSize(data.processed_size || 0)
                    + "/" + Ext.util.Format.fileSize(data.total_size);
            }
            else if (Ext.isNumber(data.total_count) && (0 < data.total_count)) {
                progressText = (data.processed_count || 0)
                    + "/" + data.total_count;
            }
            if (this.simpleProgress) {
                progressText = "<center>" + percentText + "</center>";
            }
            else {
                progressText = '<div><div style="float:left;">' + percentText
                    + '</div><div style="float: right; padding-right: 28px;">' + progressText
                    + '</div></div> </br><div style="padding-top: 5px;">' 
                    + _RC_STR("task", "time_remain") + ": " + this.getRemainTimeStr(data.remaining_time) + "</div>"
            }

            var msg = Ext.util.Format.htmlEncode(SYNO.SDS.RoboCopy.utils.parseFullPathToFileName(data.pfile || ""));
            this.getMsgBox().updateProgress(progress, progressText, 
                //Ext.util.Format.ellipsis(msg, 50, true)
                msg, true
            );
        }
    },
    getRemainTimeStr: function(time) {
        if (!time) {
            return _T("common", "unknown")
        }
        var days, hours, mins, secs, result;
        days = time / (24 * 3600);
        if (days > 1) {
            result = _RC_STR("task", "time_greater_day")
        } else {
            result = "";
            hours = parseInt(time / 3600, 10);
            mins = parseInt(time / 60 - hours * 60, 10);
//            secs = parseInt(time - mins * 60 - hours * 3600, 10);
            result += (hours >= 1) ? hours + " " + _T("status", "status_hour") + ", " : "";
            result += (mins >= 1) ? mins + " " + _T("status", "status_minute") : "";
            if (result === "") {
                result = _RC_STR("task", "time_less_min")
            }
        }
        return result;
    },
    onTaskCallBack: function (a, c, finished, progress, data) {
        _DEBUG("RoboCopy.Action.onTaskCallBack("+c+", finished:" + finished + ", progress:" + progress+")");
        if (!data) {
            return;
        }
        if ("cancel" === c) {
            this.onCancelTask(data);
        } else {
            if (finished) {
                this.onFinishTask(progress, data);
            } else {
                this.onProgressTask(progress, data);
            }
        }
    },
    showProgress: function (title, msg, a, f, c) {
        var e = null;
        if (a) {
            e = {
                ok: _WFT("common", "common_cancel")
            };
        }
        var b = {
            title: title,
            msg: msg,
            width: 300,
            progress: c,
            progressText: c ? "<center>0&#37;</center>" : "",
            cls: "syno-webfm-progress",
            closable: false,
            buttons: e,
            fn: (a ? a : null),
            hideDlg: true,
            scope: this
        };
        var d = {};
        if (f) {
            Ext.apply(d, {
                owner: this.owner || this.webfm.owner,
                tools: [{
                    id: "minimize",
                    handler: this.onMinimzieMsgBox,
                    scope: this
                }]
            });
        }
        this.getMsgBox(d).show(b);
    },
//    onMinimzieMsgBox: function () {
//        var a = this.getMsgBox().getDialog();
//        a.mon(a, "hide", function () {
//            a.doClose();
//        });
//        if (_S("standalone")) {
//            a.hide(this.webfm.monitorPanel.el);
//            this.webfm.monitorPanel.activeTabPanel("background");
//        } else {
//            var b = SYNO.SDS.AppMgr.getByAppName("SYNO.SDS.App.FileTaskMonitor.Instance")[0].getBKTray().taskButton.el;
//            a.hide(b);
//        }
//        this.blMsgMinimized = true;
//        this.sendFileTaskNotify();
//    },
//    sendFileTaskNotify: function () {
//        this.webfm.owner.sendFileTaskNotify(true, this.bkTask.id);
//    },
    hideProgress: function () {
        if (!this.blMsgMinimized && !this.isOwnerDestroyed()) {
            this.getMsgBox().hide();
        }
    },
    showErrItems: function (e) {
        this.hideProgress();
        if (this.blMsgMinimized || this.isOwnerDestroyed() || !this.isOwnerVisible()) {
            return;
        }
        var d = "";
        var c = 0;
        if (e.errno) {
            d += _WFT(e.errno.section, e.errno.key) + "<br>";
        }
        var f, b, a;
        if (e.errItems && 0 < e.errItems.length) {
            a = (e.errItems.length > 15) ? 15 : e.errItems.length;
            d += _WFT("error", "error_files");
            for (c = 0; c < a; c++) {
                f = e.errItems[c].name;
                b = f.lastIndexOf("/");
                b = (b == -1) ? 1 : b + 1;
                f = f.substr(b);
                if (f.length > 40) {
                    f = f.substr(0, 37) + "...";
                }
                d += "<br>" + Ext.util.Format.htmlEncode(f);
                if (e.errItems[c].section) {
                    d += "<br>" + _WFT(e.errItems[c].section, e.errItems[c].key);
                }
            }
            if (a < e.errItems.length) {
                d += "<br>...";
            }
        }
        if (d === "") {
            d = _WFT("common", "error_system");
        }
        this.getMsgBox().alert(this.actionText, d);
    },
    isOwnerVisible: function () {
        return (this.owner && this.owner.isVisible());
    },
    isOwnerDestroyed: function () {
        return (this.owner && this.owner.isDestroyed);
    },
    getMsgBox: function (a) {
        return this.owner.getMsgBox(a);
//    },
//    callFileBrowsers: function (fn, pArr) {
//        var fileBrowsers = SYNO.SDS.AppMgr.getByAppName("SYNO.SDS.App.FileStation3.Instance");
//        Ext.each(fileBrowsers, function (fb) {
//            var scope = fb.window.getPanelInstance();
//            eval("SYNO.FileStation.WindowPanel.superclass." + fn + ".apply(scope, pArr)")
//        })
//    },
//    setHighlightEntry: function () {
//        this.callFileBrowsers("setHighlightEntry", arguments)
//    },
//    refreshTreeNode: function () {
//        this.callFileBrowsers("refreshTreeNode", arguments)
//    },
//    refreshSearhGrid: function (a, b) {
//        this.callFileBrowsers("refreshSearhGrid", arguments)
    }
});


Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.ConfigWindow = Ext.extend(SYNO.SDS.ModalWindow, {
    constructor: function (cfg) {
        this.owner = cfg.owner;
        cfg = SYNO.LayoutConfig.fill(this.fillConfig(cfg));
        SYNO.SDS.RoboCopy.ConfigWindow.superclass.constructor.call(this, cfg);
        this.defineBehaviors();
    },
    defineBehaviors: function() {
//        if (true === _S("is_admin")) {
//            var a = new SYNO.SDS.Utils.EnableCheckGroup(this.form, "bandwidth_enable", [this.btnBandwidthSettingId])
//        }
//        if ((_D("usbcopy") !== "yes") && (_D("sdcopy") !== "yes")) {
//            this.panel.getForm().findField("run_after_usbcopy").disable();
//        }
//        this.getTabPanel().addDeactivateCheck(this);
//        this.integrationForm = this.get("tab").get("integration");
//        this.locationForm = this.get("tab").get("location");
        this.generalForm = this.get("tab").get("general");
//        SYNO.SDS.Utils.AddTip(this.generalForm.getForm().findField('compare_mode_no_meta').getEl(), 
//                                _RC_STR("ui", "format_codes"));
    },
    fillConfig: function(params) {
        var tabs = [];
        tabs.push(this.fillGeneralTab());
        if (isDsmV4()) {
            tabs.push(this.fillIngerationTab());
        }
        tabs.push(this.fillLocationTab());
        //
        var cfg = {
            title: _RC_STR("config", "title"),
            resizable: false,
            layout: "fit",
            width: 500,
//            height: 300,
            autoHeight: true,
            padding: "10px",
            border: false,
            items: [{
                xtype: getXType("syno_tabpanel", "tabpanel"),
                plain: true,
                itemId: "tab",
                activeTab: 0,
                items: tabs
            }],
            buttons: [{
                text: _T("common", "ok"),
                btnStyle: "blue",
                scope: this,
                handler: this.saveHandler,
            }, {
                text: _T("common", "cancel"),
                scope: this,
                handler: this.closeHandler
            }],
            keys: [{
                key: [10, 13],
                fn: this.saveHandler,
                scope: this
            }, {
                key: 27,
                fn: this.closeHandler,
                scope: this
            }],
            listeners: {
                scope: this,
                single: true,
                afterlayout: this.onAfterLayout
            }
        };

        return Ext.apply(params, cfg);
    },
    fillGeneralTab: function() {
        var a = {
            xtype: "form", //getXType("syno_formpanel" ,"form"),
            itemId: "general",
            border: false,
            autoHeight: true,
            padding: 20,
            trackResetOnLoad: true,
            title: _RC_STR("config", "general"),
            items: [{
                xtype: getXType("syno_fieldset", "fieldset"),
                title: _RC_STR("config", "compare_title"),
                items: [{
//                    synotype: "desc",
//                    value: _RC_STR("config", "compare_desc"),
//                    indent: 1
//                }, {
                    itemId: "compare_mode_full",
                    synotype: "radio",
                    name: "compare_mode",
                    inputValue: "full",
                    boxLabel: _RC_STR("config", "compare_binary"),
                    checked: true,
                    indent: 1
                }, {
                    itemId: "compare_mode_no_meta",
                    synotype: "radio",
                    name: "compare_mode",
                    inputValue: "no_meta",
                    boxLabel: _RC_STR("config", "compare_no_meta"),
                    indent: 1
                }, {
                    synotype: "desc",
                    itemId: "compare_mode_no_meta_note",
                    fieldLabel: "Note",
                    hideLabel: true,
                    indent: 2,
                    htmlEncode: false,
                    value: _RC_STR("config", "compare_no_meta_note")
                }]
            }, {
                xtype: getXType("syno_fieldset", "fieldset"),
                title: _RC_STR("config", "conflict_policy"),
                items: [{
//                    synotype: "desc",
//                    value: _RC_STR("config", "conflict_policy"),
//                    indent: 1
//                }, {
                    itemId: "conflict_policy_skip",
                    synotype: "radio",
                    name: "conflict_policy",
                    inputValue: "skip",
                    boxLabel: _RC_STR("config", "skip"),
                    checked: true,
                    indent: 1
                }, {
                    itemId: "conflict_policy_rename",
                    synotype: "radio",
                    name: "conflict_policy",
                    inputValue: "rename",
                    boxLabel: _RC_STR("config", "rename"),
                    indent: 1
                }, {
                    itemId: "conflict_policy_overwrite",
                    synotype: "radio",
                    name: "conflict_policy",
                    inputValue: "overwrite",
                    boxLabel: _RC_STR("config", "overwrite"),
                    indent: 1
                }]
            }]
        };
        return a;
    },
    fillIngerationTab: function() {
        var a = {
            xtype: "form", //getXType("syno_formpanel" ,"form"),
            itemId: "integration",
            border: false,
            autoHeight: true,
            padding: 20,
            trackResetOnLoad: true,
            title: _RC_STR("config", "integration"),
            items: [{
                xtype: getXType("syno_fieldset", "fieldset"),
                title: _RC_STR("config", "autorun"),
                items: [{
                    synotype: "check",
                    name: "run_after_usbcopy",
                    disabled: ((_D("usbcopy", "no") === "no") && (_D("sdcopy", "no") === "no")),
                    boxLabel: _RC_STR("config", "run_after_usbcopy")
                }, {
                    synotype: "check",
                    name: "run_on_attach_disk",
                    boxLabel: _RC_STR("config", "run_on_attach_disk")
                }]
            }]
        };
        return a;
    },
    fillLocationTab: function () {
        var a = {
            xtype: "form", //getXType("syno_formpanel" ,"form"),
            itemId: "location",
            border: false,
            autoHeight: true,
            padding: 20,
            trackResetOnLoad: true,
            title: _RC_STR("config", "location"),
            items: [{
                xtype: getXType("syno_fieldset", "fieldset"),
                title: _RC_STR("config", "locator"),
                items: [{
                    synotype: "number",
                    fieldLabel: _RC_STR("config", "threshold"),
                    width: 200,
                    minValue: 100,
                    maxValue: 10000,
                    allowBlank: false,
//                    blankText: "Trashold may be not empty",
                    name: "locator_threshold"
                },{
                    synotype: "combo",
                    name: "locator_language",
                    width: 200,
                    fieldLabel: _RC_STR("config", "language"),
                    store: [
                        ["en", _T("common", "language_enu")],
                        ["fr", _T("common", "language_fre")],
                        ["de", _T("common", "language_ger")],
                        ["it", _T("common", "language_ita")],
                        ["�s", _T("common", "language_spn")],
//                        ["cht", _T("common", "language_cht")],
//                        ["chs", _T("common", "language_chs")],
//                        ["jpn", _T("common", "language_jpn")],
//                        ["krn", _T("common", "language_krn")],
//                        ["ptb", _T("common", "language_ptb")],
                        ["ru", _T("common", "language_rus")]
//                        ["dan", _T("common", "language_dan")],
//                        ["nor", _T("common", "language_nor")],
//                        ["sve", _T("common", "language_sve")],
//                        ["nld", _T("common", "language_nld")],
//                        ["plk", _T("common", "language_plk")],
//                        ["ptg", _T("common", "language_ptg")],
//                        ["hun", _T("common", "language_hun")],
//                        ["trk", _T("common", "language_trk")],
//                        ["csy", _T("common", "language_csy"])
                    ]
                }]
            }]
        };
        return a;
    },
    getAllForms: function() {
        var result = [];
        var tab = this.get("tab");
        if (tab) {
            tab.items.each(function(e,b,d) {
                if (e.getForm) {
                    var frm = e.getForm();
                    result.push(frm);
                }
            }, this);
        }
        return result;
    },
    isAnyFormDirty: function () {
        var a = this.getAllForms();
        var b = false;
        Ext.each(a, function(e, c, d) {
            if (e.isDirty()) {
                b = true;
                return false
            }
        }, this);
        return b
    },
    isAllFormValid: function() {
        var result = true;
        var tab = this.get("tab");
        if (tab) {
            tab.items.each(function(v,i,a) {
                if (v.getForm) {
                    var frm = v.getForm();
                    if (!frm.isValid()) {
                        result = false;
                        tab.setActiveTab(i);
                        return false
                    }
                }
            }, this);
        }
        return result;
    },
    onAfterLayout: function() {
        this.setStatusBusy();
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            params: {
                action: "settings"
            },
            callback: function(a, c, b) {
                this.clearStatusBusy();
                if (!b.success) {
                    this.getMsgBox().alert(this.title, 
                        SYNO.SDS.RoboCopy.GetErrorMessage(b.errinfo),
                        function(){
                            this.close();
                        }, this);
                    return
                }
                Ext.each(this.getAllForms(), function(itm, idx, all) {
                    itm.setValues(b.data);
                }, this);
            },
            scope: this
        }).start(true)
    },
    saveHandler: function() {
        if (!this.isAllFormValid()) {
            return;
        }
        if (!this.isAnyFormDirty()) {
            this.close();
            return
        }
        var params = {};
        Ext.each(this.getAllForms(), function(f,i,a){
//            console.log("Get values from ", f);
            var d = f.getFieldValues();
//            var d = f.getValues();
            Ext.apply(params, d);
        }, this);
        
        if (this.generalForm) {
            Ext.apply(params, {
                conflict_policy: this.generalForm.getForm().findField("conflict_policy").getGroupValue(),
                compare_mode: this.generalForm.getForm().findField("compare_mode").getGroupValue(),
            });
        }
        this.setStatusBusy({
            text: _T("common", "saving")
        });
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            method: "POST",
            params: Ext.apply(params, {
                action: "settings"
            }),
            callback: function(c, f, d) {
                this.clearStatusBusy();
                if (!f || !d) {
                    this.getMsgBox().alert(_T("tree", "leaf_packagemanage"), _T("common", "error_system"));
                    return
                }
                if (!d.success || 0 > d.data.progress) {
                    var e = _T("error", "error_system_busy");
                    if (d.errinfo && d.errinfo.sec && d.errinfo.key) {
                        e = _T(d.errinfo.sec, d.errinfo.key)
                    }
                    this.getMsgBox().alert(_T("tree", "leaf_packagemanage"), e)
                } else {
                    this.close()
                }
            },
            scope: this
        }).start(true)
    },
    closeHandler: function() {
        if (this.isAnyFormDirty()) {
            this.getMsgBox().confirm(this.title, _T("common", "confirm_lostchange"), 
                function(a) {
                    if ("yes" == a) {
                        this.close()
                    } else {
                        return
                    }
                }, this)
        } else {
            this.close()
        }
    }
});


Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.RuleEdit = Ext.extend(SYNO.SDS.ModalWindow, {
    constructor: function (cfg) {
        this.owner = cfg.owner;
        this.action = (cfg.id) ? "rule_edit" : "rule_add";
        this.item_id = cfg.id;
        this.name = cfg.name;
//        Ext.QuickTips.init();
        var title = "";
        if (cfg.id) {
//            title = String.format(_RC_STR("ui", "edit_item"), this.name)
            title = _RC_STR("ui", "edit_item");
        } else {
//            title = String.format(_RC_STR("ui", "create_item"), "")
            title = _RC_STR("ui", "create_item");
        }
        this.panel = this.createPanel(cfg);
        //
        cfg = Ext.apply({
            title: title,
            resizable: false,
            layout: "fit",
            width: 560,
//            height: 320,
            autoHeight: true,
            buttons: [{
                text: _T("common", "ok"),
                btnStyle: "blue",
                scope: this,
                handler: this.apply
            }, {
                text: _T("common", "cancel"),
                scope: this,
                handler: this.close
            }],
            items: [this.panel]
        }, cfg);
 
        SYNO.SDS.RoboCopy.RuleEdit.superclass.constructor.call(this, cfg);
        this.mon(this.panel, "afterlayout", function (c, d) {
            SYNO.SDS.Utils.AddTip(this.panel.getForm().findField('mai_info_dest_dir').getEl(), 
                                _RC_STR("ui", "format_codes"));
            SYNO.SDS.Utils.AddTip(Ext.getCmp("mai_info_dest_file").getEl(), 
                _RC_STR("ui", "format_codes"));
//            SYNO.SDS.Utils.AddTip(Ext.getCmp("mai_info_dest_ext").getEl(), _RC_STR("ui", "format_codes"));
        }, this, {
            single: true
        });
    },
    apply: function () {
        if (!this.panel.getForm().isValid()) {
            return;
        }
        this.setStatusBusy({
            text: _T("common", "saving")
        });
        var request = {
            action: this.action,
            id: this.item_id,
            priority: Ext.getCmp("mai_info_priority").getValue(),
            description: Ext.getCmp("mai_info_description").getValue(),
//            src_dir: Ext.getCmp("mai_info_src_dir").getValue(),
            src_ext: Ext.getCmp("mai_info_src_ext").getValue(),
            dest_folder: Ext.getCmp("mai_info_dest_folder").getValue(),
            dest_dir: Ext.getCmp("mai_info_dest_dir").getValue(),
            dest_file: Ext.getCmp("mai_info_dest_file").getValue(),
//            dest_ext: Ext.getCmp("mai_info_dest_ext").getValue(),
            src_remove: Ext.getCmp("mai_info_src_remove").getValue().inputValue
        };
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            method: 'POST',
            params: request,
            callback: function(a, c, b) {
                this.clearStatusBusy();
                if (!b.success) {
                    this.getMsgBox().alert(this.title, 
                        SYNO.SDS.RoboCopy.GetErrorMessage(b.errinfo));
                }
                else {
                    this.close();
                }
            },
            scope: this
        }).start(true)
    },
    createPanel: function(params) {
        var storeShares = new Ext.data.JsonStore({
                autoLoad: true,
                baseParams: {
                    action: "share_list",
                },
                url: SYNO.SDS.RoboCopy.CGI,
                fields: [ "name", "comment" ],
                root: "data"
            });
            
        var cfg = {
            autoHeight: true,
            padding: 20,
            labelWidth: 150,
            border: false,
            items: [{
                synotype: "number",
                fieldLabel: _RC_STR("ui", "priority"),
                minValue: 1,
                maxlength: 4,
                allowBlank: false,
                blankText: "Priority may be not empty",
                id: "mai_info_priority",
                name: "priority",
                value: params.priority
            },{
                synotype: "text",
                fieldLabel: _RC_STR("ui", "description"),
                maxlength: 255,
                id: "mai_info_description",
                name: "description",
                width: 300,
                value: params.description
            },{
                synotype: "text",
                fieldLabel: _RC_STR("ui", "src_ext"),
                id: "mai_info_src_ext",
                name: "src_ext",
                value: params.src_ext
            },{
//                synotype: "text",
//                fieldLabel: _RC_STR("ui", "src_dir"),
//                id: "mai_info_src_dir",
//                width: 300,
//                value: params.src_dir
//            },{
                xtype: "radiogroup",
                id: "mai_info_src_remove",
                itemId: "src_remove",
                fieldLabel: _RC_STR("ui", "src_remove"),
//                fieldLabel: "Action",
//                columns: 1,
//                vertical: true,
                items: [{
                    boxLabel: _RC_STR("ui", "action_copy"),
                    inputValue: 0,
                    name: "src_remove",
                    checked: !params.src_remove
                }, {
                    boxLabel: _RC_STR("ui", "action_move"),
                    name: "src_remove",
                    inputValue: 1,
                    checked: params.src_remove
                }]
             },{
                synotype: "combo",
                fieldLabel: _RC_STR("ui", "dest_folder"),
                id: "mai_info_dest_folder",
                name: "dest_folder",
                editable: false,
                store: storeShares,
                forceSelection: true,
                allowBlank: false,
                displayField: "name",
                valueField: "name",
                typeAhead: true,
                triggerAction: "all",
                value: params.dest_folder,
                queryMode: 'remote'
            },{
                synotype: "text",
                fieldLabel: _RC_STR("ui", "dest_dir"),
                id: "mai_info_dest_dir",
                name: "dest_dir",
                width: 300,
                value: params.dest_dir,
                boxLabel: ""
            },{
                synotype: "text",
                fieldLabel: _RC_STR("ui", "dest_file"),
                id: "mai_info_dest_file",
                name: "dest_file",
                width: 300,
                value: params.dest_file
//            },{
//                synotype: "text",
//                fieldLabel: _RC_STR("ui", "dest_ext"),
//                id: "mai_info_dest_ext",
//                value: params.dest_ext
//            }, {
//                synotype: "check",
//                id: "mai_info_src_remove",
//                boxLabel: _RC_STR("ui", "src_remove"),
//                checked: params.src_remove
            }]
        };
        SYNO.LayoutConfig.fill(cfg);
        return new Ext.form.FormPanel(cfg);
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.Launcher = Ext.extend(SYNO.SDS.AppInstance, {
    constructor: function () {
//        _DEBUG("SYNO.SDS.RoboCopy.Launcher.constructor");
        SYNO.SDS.RoboCopy.Launcher.superclass.constructor.apply(this, arguments);
    },
    onOpen: function (a) {
//        _DEBUG("SYNO.SDS.RoboCopy.Launcher.onOpen");
        this.getBackgroundTasks();
        return SYNO.SDS.RoboCopy.Launcher.superclass.onOpen.apply(this, arguments);
    },
    onRequest: function(a) {
//        _DEBUG("SYNO.SDS.RoboCopy.Launcher.onRequest");
        this.getBackgroundTasks();
        return SYNO.SDS.RoboCopy.Launcher.superclass.onRequest.apply(this, arguments);
    },
    getBackgroundTasks: function() {
//        _DEBUG("SYNO.SDS.RoboCopy.Launcher.getBackgroundTasks");
        Ext.Ajax.request({
            url: SYNO.SDS.RoboCopy.CGI,
            method: 'POST',
            params: {
                action: "task_list"
            },
            callback: function(options, success, response) {
//                _DEBUG("SYNO.SDS.RoboCopy.Launcher.getBackgroundTasks: " + success);
//                _DEBUG(response);
                try {
                    if (success) {
                        var obj = Ext.decode(response.responseText);
                        if (obj && obj.success) {
                            _DEBUG("SYNO.SDS.RoboCopy.Launcher.getBackgroundTasks", obj);
                            if (!obj.data || !Ext.isArray(obj.data) || !obj.data[0]) {
                                return;
                            }
                            var task = obj.data[0];
//                            _DEBUG("SYNO.SDS.RoboCopy.Launcher: AppLaunch");
                            SYNO.SDS.AppLaunch("SYNO.SDS.RoboCopy.Instance", 
                                {
                                    task_id: task.id
                                }, 
                                false);
                        }
                    }
                }
                catch(e){}
            },
            scope: this
        });
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.Instance = Ext.extend(SYNO.SDS.AppInstance, {
    appWindowName: "SYNO.SDS.RoboCopy.MainWindow",
    constructor: function () {
        SYNO.SDS.RoboCopy.Instance.superclass.constructor.apply(this, arguments);
    }
});

SYNO.SDS.RoboCopy.MainWindow = Ext.extend(SYNO.SDS.AppWindow, {
    pageSize: 50,
    constructor: function (cfg) {
//        me = this;
        var store = new Ext.data.JsonStore({
            autoLoad: true,
            baseParams: {
                action: "rule_list",
                start: 0,
                limit: this.pageSize
            },
            url: SYNO.SDS.RoboCopy.CGI,
            fields: [
                'id', {name:'priority', type: 'int'},// 'src_dir', 
                'src_ext', {name:'src_remove', type: 'boolean'},
                'dest_folder', 'dest_dir', 'dest_file', 'dest_ext', 'description'
            ],
            totalProperty: 'total',
            root: "data",
            remoteSort: false
//            defaultSortable: true
        });

        this.grid = this.createGridPanel(store);

        cfg = Ext.apply({
//            resizable: false,
            maximizable: false,
            minimizable: true,
            showHelp: false,
            width: 800,
            minWidth: 800,
            minHeight: 300,
            height: 500,
            layout: "fit",
            items: [this.grid]
//            .buttons: [{
//                text: _T("common", "ok"),
//                scope: this,
//                handler: function () {
//                    this.close(); //me.close()
//                }
//            }]
        }, cfg);
        SYNO.SDS.RoboCopy.MainWindow.superclass.constructor.call(this, cfg);
        this.mon(this.grid, "rowdblclick", this.handleEdit, this);
        this.mon(this.grid, "rowclick", this.checkButtonStat, this);
        this.mon(this.grid.store, "load", this.checkButtonStat, this);

        this.checkButtonStat();
        
    },
    onOpen: function (a) {
        SYNO.SDS.RoboCopy.MainWindow.superclass.onOpen.apply(this, arguments);
        return this.onRequest.call(this, a);
    },
    onRequest: function(a) {
        if (a) {
            if (a.folders && Ext.isArray(a.folders) && (a.folders.length > 0)) {
                this.runProcess(a.folders, a.src_remove);
            }
            if (a.task_id) {
                this.addBkTask({
                    bkTaskCfg: {
                        taskid: a.task_id
                    }
                });
            }
        }
        return SYNO.SDS.RoboCopy.MainWindow.superclass.onRequest.apply(this, arguments);
    },
    
    checkButtonStat: function () {
        if (this.grid.getSelectionModel().hasSelection()) {
            Ext.getCmp("mai_remove_button").setDisabled(false);
            Ext.getCmp("mai_edit_button").setDisabled(false)
        } else {
            Ext.getCmp("mai_remove_button").setDisabled(true);
            Ext.getCmp("mai_edit_button").setDisabled(true)
        }
    },

//    createStore0: function (fields) {
//        return new Ext.data.ArrayStore({
//                fields: fields,
//                data: [
//                    [1, "jpg", "photo", "123"],
//                    [2, "mov", "video", "456"]
//                ]
//            });
//    },
    createGridPanel: function (store) {
        var result;
        var cfg;
        cfg = {
            itemId: "grid",
            border: false,
            store: store,
            sm: new Ext.grid.RowSelectionModel({
                singleSelect: true
            }),
            loadMask: true,
            enableHdMenu: false,
            columns: [{
                header:  _RC_STR("ui", "priority_short"),
                dataIndex: "priority",
                id: "mai_grid_priority",
                sortable: true,
                width: 50
            }, {
                header:  _RC_STR("ui", "src_ext_short"),
                dataIndex: "src_ext",
                id: "mai_grid_src_ext",
                width: 50
            }, {
//                header:  _RC_STR("ui", "src_dir_short"),
//                dataIndex: "src_dir",
//                id: "mai_grid_src_dir",
//                width: 100
//            }, {
                header:  _RC_STR("ui", "src_remove_short"),
                dataIndex: "src_remove",
                id: "mai_grid_src_remove",
                width: 50,
                renderer: function(value, metaData, record, rowIndex, colIndex, store) {
                    var action = (value ? "action_move" : "action_copy"); 
                    metaData.attr = 'ext:qtip="' + _RC_STR("ui", action) + '"';
                    return '<img width="16" height="16" src="' + SYNO.SDS.RoboCopy.PIC_PREFIX + action + '.png" >';
                }
            }, {
                header:  _RC_STR("ui", "dest_folder_short"),
                dataIndex: 'dest_folder',
                id: "mai_grid_dest_folder",
                width: 100
            }, {
                header:  _RC_STR("ui", "dest_dir_short"),
                dataIndex: 'dest_dir',
                id: "mai_grid_dest_dir",
                width: 250 //150
            }, {
                header:  _RC_STR("ui", "dest_file_short"),
                dataIndex: 'dest_file',
                id: "mai_grid_dest_file",
                width: 150
//            }, {
//                header:  _RC_STR("ui", "dest_ext_short"),
//                dataIndex: 'dest_ext',
//                id: "mai_grid_dest_ext",
//                width: 50
            }, {
                header:  _RC_STR("ui", "description_short"),
                dataIndex: 'description',
                id: "mai_grid_description"
            }],
            autoExpandColumn: "mai_grid_description",
            tbar: {
                defaultType: getXType('syno_button', 'button'),
                items: [{
                    text: _T("common", "add"),
                    handler: this.handleAdd,
                    scope: this
                }, {
                    text: _T("common", "alt_edit"),
                    disabled: true,
                    id: "mai_edit_button",
                    handler: this.handleEdit,
                    scope: this
                }, {
                    text: _T("common", "remove"),
                    disabled: true,
                    id: "mai_remove_button",
                    handler: this.handleRemove,
                    scope: this
                }, 
//                '-',
                { xtype: 'tbspacer', width: 30 },
                {
                    text: _RC_STR("ui", "run_now"),
                    handler: this.handleRunNow,
                    scope: this
                },
                '->',
                {
                    text: _RC_STR("ui", "config"),
                    handler: this.handleConfig,
                    scope: this
                }]
            },
            bbar: new Ext.PagingToolbar({
                store: store,
                displayInfo: true,
                pageSize: this.pageSize
            })
        };
        result = new Ext.grid.GridPanel(cfg);
        return result;
    },
    handleAdd: function () {
        this.openInfo();
    },
    handleEdit: function () {
        var rec = null;
        if (this.grid.getSelectionModel().hasSelection()) {
            rec = this.grid.getSelectionModel().getSelections()[0];
        }
        this.openInfo(rec.json);
    },
    handleRemove: function () {
        var selected = null;
        if (this.grid.getSelectionModel().hasSelection()) {
            selected = this.grid.getSelectionModel().getSelections()[0];
        } else {
            return;
        }
        var callback = function (btnID, text, opt) {
            if ("yes" !== btnID) {
                return;
            }
            this.setStatusBusy();
            this.addAjaxTask({
                single: true,
                autoJsonDecode: true,
                url: SYNO.SDS.RoboCopy.CGI,
                method: 'POST',
                params: {
                    action: "rule_remove",
                    id: selected.get("id")
                },
                callback: function(a, c, response) {
                    this.clearStatusBusy();
                    if (!response || !response.success) {
                        this.getMsgBox().alert(_T("error", "error_error"), 
                            SYNO.SDS.RoboCopy.GetErrorMessage(response.errinfo));
                    }
                    this.refresh();
                },
                scope: this
            }).start(true)
        };
        this.getMsgBox().confirm(this.title, _RC_STR("ui", "remove_confirm"), callback, this);
    },
    handleRunNow: function () {
        //this.RELURL = this.jsConfig.jsBaseURL + "/webfm/";
        this.RELURL = "/webfm/";
        if (!this.selTree || this.selTree.isDestroyed) {
            this.selTree = new SYNO.FileStation.SelTreeDialog({
                    RELURL: this.RELURL,
                    owner: this
            });
            //this.selTree.mon(this.selTree, "beforesubmit", this.onCheckPrivilege, this);
            this.selTree.mon(this.selTree, "callback", this.onRunSelected, this)
        }
        var title = _RC_STR("ui", "select_for_run");
        //this.selTree.load(_RC_STR("app", "app_name"));
        this.selTree.title = title;
        this.selTree.setTitle(title);
        this.selTree.show();
    },
    onCheckPrivilege: function(a, b) {
        if (_S("is_admin") === true || _S("domainUser") == "true") {
            return true
        }
        var result = true;
//        Ext.each(b, function(f) {
//            var d = (f.parentNode.id != "fm_root") ? SYNO.webfm.utils.getShareRight(a, f) : f.attributes.right;
//            if (!SYNO.webfm.utils.checkShareRight(d, SYNO.webfm.utils.RW | SYNO.webfm.utils.RO)) {
//                this.owner.getMsgBox().alert(_WFT("filetable", "filetable_search"), 
//                    _WFT("error", "error_privilege_not_enough"));
//                c = false;
//                return true
//            }
//            var e = 0;
//            if (_S("is_admin") === true) {} else {
//                if (f.parentNode.id != "fm_root") {
//                    e = SYNO.webfm.utils.getShareFtpRight(a, f)
//                } else {
//                    e = f.attributes.ftpright
//                }
//            }
//            c = (e & SYNO.webfm.utils.FTP_PRIV_DISABLE_LIST);
//            if (c) {
//                this.owner.getMsgBox().alert(_WFT("filetable", "filetable_search"), 
//                    _WFT("error", "error_privilege_not_enough"));
//                c = false;
//                return true
//            }
//        }, this);
        return result
    },
    onRunSelected: function(a, b) {
        var folders = [];
        Ext.each(b, function(f, idx) {
            var real_path = f.attributes.real_path || f.attributes.path;
            if (!real_path || (-1 != folders.indexOf(real_path))) {
                return
            }
            folders.push(real_path)
        }, this);
        this.runProcess(folders);
    },
    handleConfig: function() {
        if (!this.SettingDialog || this.SettingDialog.isDestroyed) {
            _DEBUG("Create settnig dialog");
            this.SettingDialog = new  SYNO.SDS.RoboCopy.ConfigWindow({
                owner: this
            });
        }
        this.SettingDialog.show();
    },
    openInfo: function (item) {
        var edt = null;
        var cfg = {
            owner: this
        };
        cfg = Ext.apply(cfg, item);
        edt = new SYNO.SDS.RoboCopy.RuleEdit(cfg);
        this.mon(edt, "close", this.refresh, this);
        edt.open();
    },
    refresh: function () {
        this.checkButtonStat();
        this.grid.getStore().reload();
        this.grid.getView().refresh();
    },
    runProcess: function (folders, src_remove) {
        if (!folders || (folders.length == 0)) {
            return;
        }
        this.setStatusBusy();
        var params = {
                    action: "task_run",
                    folders: folders.join("|"),
                };
        if (Ext.isDefined(src_remove)) {
            params = Ext.apply(params, {src_remove: src_remove});
        }
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            method: 'POST',
            params: params,
            callback: function(a, success, response) {
                this.clearStatusBusy();
                this.onRunDone(success && response && response.success, response, folders);
            },
            scope: this
        }).start(true)
    },
    onRunDone: function (success, response, folders) {
        if (!success) {
            this.getMsgBox().alert(_T("error", "error_error"), 
                SYNO.SDS.RoboCopy.GetErrorMessage(response.errinfo));
        }
        else {
            this.addBkTask({
                bkTaskCfg: {
                    taskid: response.taskid
                },
                actionCfg: {
                    fileStr: SYNO.SDS.RoboCopy.utils.ParseArrToFileName(folders)
//                    srcIdArr: c,
//                    destId: d
                }
            });
        }
    },
    addBkTask: function (config, bkTask) {
        var cfg = {
            owner: config.owner || this,
            bkTaskCfg: {
                url: SYNO.SDS.RoboCopy.CGI
            },
            msgCfg: {
                progress: true,
                msg: _WFT("common", "calculating")
            },
//            actionStr: {
//                section: "ui", //"filetable",
//                key: "action_copy" //"filetable_copy"
//            },
//            actingStr: {
//                section: "filetable",
//                key: "filetable_copying"
//            },
            actionCfg: {
                starttime: new Date().getTime() / 1000
            }
        };
        Ext.apply(cfg.bkTaskCfg, config.bkTaskCfg || {});
        Ext.apply(cfg.msgCfg, config.msgCfg || {});
        Ext.apply(cfg.actionCfg, config.actionCfg || {});
        var t = new SYNO.SDS.RoboCopy.Action(cfg, bkTask);
    }
});


