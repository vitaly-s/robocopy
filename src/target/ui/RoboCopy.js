/* Copyright (c) 2013 Vitaly Shpachenko. All rights reserved. */

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.PIC_PREFIX = "3rdparty/robocopy/images/";
SYNO.SDS.RoboCopy.CGI = "/webman/3rdparty/robocopy/robocopy.cgi";
//SYNO.SDS.RoboCopy.TestCGI = "/webman/3rdparty/robocopy/test.cgi";


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
    checkFn: function(a, c) {
        //["file_id", "filename", "filesize", "mt", "ct", "at", "privilege_str", "privilege", "owner", "group", "icon", "type", "path", "isdir", "uid", "gid", "is_compressed"]),
        if (1 !== c.length || !c[0].get("isdir")) {
            return false;
        }
        var apps = SYNO.SDS.AppMgr.getByAppName("SYNO.SDS.RoboCopy.Instance");
        if (!apps || 0 === apps.length) {
            return true;
        }
        var mb = apps[0].window.getMsgBox(); //.getDialog();
        return !mb || !mb.isVisible();
//        return true;
    },
    launchFn: function(b) {
        SYNO.SDS.AppLaunch("SYNO.SDS.RoboCopy.Instance", 
            {
                fb_recs: b
            }, 
            false);
    }
});

SYNO.SDS.RoboCopy.SelectFolderTreePanel = Ext.extend(Ext.tree.TreePanel, {
    constructor: function (b) {
        this.startButtonId = b.okBtnID;
        this.preCheckFolder = b.preCheckFolder;
        this.treeroot = new Ext.tree.AsyncTreeNode({
            cls: "root_node",
            text: _S("hostname"),
            icon: SYNO.SDS.RoboCopy.PIC_PREFIX + "my_ds.png",
            draggable: false,
            expanded: true,
            id: "fm_root",
            allowDrop: false,
            uiProvider: Ext.tree.TriTreeNodeUI
        });
        this.dirTreeLoader = new Ext.tree.TreeLoader({
            dataUrl: "/webman/modules/FileBrowser/webfm/webUI/file_share.cgi",
            baseParams: {
                action: "getshares",
                needrw: "false",
                bldisableist: "true"
            },
            baseAttrs: {
                uiProvider: Ext.tree.TriTreeNodeUI
            },
            listeners: {
                beforeload: {
                    fn: function (e, d, c) {
                        return !(true == d.disabled)
                    },
                    scope: this
                },
                load: {
                    scope: this,
                    fn: function (h, g, c) {
                        if (g.id == this.treeroot.id) {
                            this.attachCheckChangeHandler();
                        }
                        if (c.responseText) {
                            var e = Ext.util.JSON.decode(c.responseText);
                            if (e && e.errno) {
                                this.getMsgBox().alert(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "error", "connection_error"));
                            } else {
                                for (var f = 0; f < e.length; f++) {
                                    g.childNodes[f].realPath = e[f].path;
                                    for (var d = 0; d < this.preCheckFolder.length; d++) {
                                        if (this.preCheckFolder[d] == g.childNodes[f].realPath) {
                                            g.childNodes[f].getUI().toggleCheck(true);
                                            continue;
                                        }
                                        if (0 == this.preCheckFolder[d].indexOf(g.childNodes[f].realPath)) {
                                            g.childNodes[f].expand();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            createNode: function (c) {
//                switch (c.text) {
//                case "@quarantine":
//                case "#recycle":
//                    c.hidden = true;
//                    break;
//                default:
//                    break
//                }
                return Ext.tree.TreeLoader.prototype.createNode.call(this, c)
            }
        });
        var a = {
            animate: false,
            autoScroll: true,
            loader: this.dirTreeLoader,
            containerScroll: true,
            enableDD: false,
            rootVisible: true,
            border: false,
            useArrows: true,
            root: this.treeroot,
            tbar: [],
            listeners: {
                beforedestroy: {
                    fn: function () {
                        Ext.destroy(this.dirTree);
                    },
                    scope: this
                }
            },
            getChecked: function (c, e, d) {
                e = e || this.root;
                var g = d || [];
                var f = e.firstChild;
                do {
                    switch (f.getUI().getCheckIndex(f)) {
                    case Ext.tree.TriTreeNodeUI.GRAYSTATE:
                        if (f.firstChild) {
                            this.getChecked(c, f, g);
                        } else {
                            this.getMsgBox().alert(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "error", "execution_failed"));
                        }
                        break;
                    case Ext.tree.TriTreeNodeUI.CHECKSTATE:
                        g.push(!c ? f : (c == "id" ? f.id : f.attributes[c]));
                        break;
                    default:
                        break;
                    }
                    f = f.nextSibling;
                } while (f);
                return g;
            }
        };
        Ext.apply(a, b);
        SYNO.LayoutConfig.fill(a);
        SYNO.SDS.RoboCopy.SelectFolderTreePanel.superclass.constructor.call(this, a);
    },
    attachCheckChangeHandler: function () {
        this.on("checkchange", this.checkCheckedSelection, this);
        this.fireEvent("checkchange");
    },
    checkCheckedSelection: function () {
        var a = this.getChecked();
        if (0 == a.length) {
            Ext.getCmp(this.startButtonId).disable();
        } else {
            Ext.getCmp(this.startButtonId).enable();
        }
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.Request = Ext.extend(Ext.util.Observable, {
    constructor: function (cfg) {
        this.reqConfig = this.applyRequestConfig(cfg);
        SYNO.SDS.RoboCopy.Request.superclass.constructor.call(this)
    },
    applyRequestConfig: function (cfg) {
        this.cbHandler = Ext.copyTo({}, cfg, ["scope", "callback"]);
        var result = Ext.apply(cfg, {
            method: cfg.method || "POST",
            callback: this.onSendDone,
            scope: this
        });
        return result;
    },
    send: function () {
        Ext.Ajax.request(this.reqConfig);
    },
    onSendDone: function (options, success, response) {
        var scope = this.cbHandler.scope;
        var callback = this.cbHandler.callback;
        if (!success || !response.responseText) {
            callback.call(scope, options , false, {
                sec: "error",
                key: "commfail"
            });
            return;
        }
        var obj;
        try {
           obj = Ext.decode(response.responseText);
        }
        catch(e) {}
        if (!obj) {
            callback.call(scope, options , false, {
                sec: "error",
                key: "commfail"
            });
            return;
        }
        if (!obj.success) {
            if (obj.errinfo && obj.errinfo.sec && obj.errinfo.key) {
                callback.call(scope, options, false, obj.errinfo);
            }
            else {
                callback.call(scope, options , false, {
                    sec: "error",
                    key: "commfail"
                });
            }
        } else {
            callback.call(scope, options, true, obj);
        }
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.Action = Ext.extend(Ext.Component, {
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
                        action: "readprogress",
                        taskid: taskid
                    }
                },
                cancel: {
                    url: config.bkTaskCfg.url,
                    params: {
                        action: "cancelprogress",
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
            this.showProgress(this.actionText, e, this.onCancelCallBack.createDelegate(this, [bkTask]), true, config.msgCfg.progress)
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
        this.actionText = _TT("SYNO.SDS.RoboCopy.Instance", "app", "app_name");
//        this.actingText = "actingText"; //SYNO.webfm.utils.getLangText(this.actingStr)
    },
    genBkTitle: function (a, b) {
        return ["{0}: {1}", _TT("SYNO.SDS.RoboCopy.Instance", "app", "app_name"), b];
    },
    onCancelCallBack: function (a) {
        a.cancel()
    },
    onCancelTask: function (c) {
        this.hideProgress();
        if (c.errno && c.errno.section && c.errno.key) {
//            var a = c.errno;
//            var b = _WFT(a.section, a.key);
//            this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
//            if (this.isOwnerDestroyed() || !this.isOwnerVisible()) {
//                SYNO.SDS.SystemTray.notifyMsg("SYNO.SDS.App.FileStation3.Instance", this.actionText, b)
//            } else {
//                this.getMsgBox().alert(this.actionText, b)
//            }
        }
    },
    onFinishTask: function (a, b) {
        if ((b.result && b.result == "fail") || a === -1) {
            this.showErrItems(b);
        } else {
            this.onCompleteTask(b);
        }
    },
    onCompleteTask: function (a) {
        this.hideProgress();
//        this.refreshTreeNode(this.srcIdArr, this.destId, "move" == this.action && a.bldir);
//        if (Ext.isDefined(a.sdbid) && Ext.isDefined(a.sdbvol)) {
//            this.refreshSearhGrid(a.sdbid, a.sdbvol)
//        }
    },
    onProgressTask: function (progress, data) {
        if (this.blMsgMinimized || this.isOwnerDestroyed()) {
            return;
        }
        if (progress && data.pfile && 0 < progress) {
            var percent = (progress * 100).toFixed(0);
            var progressText = "<center>" + percent + "&#37;</center>";
            var msg = SYNO.SDS.RoboCopy.utils.parseFullPathToFileName(data.pdir) + " / " + SYNO.SDS.RoboCopy.utils.parseFullPathToFileName(data.pfile);
            this.getMsgBox().updateProgress(progress, progressText, msg);
        }
    },
    onTaskCallBack: function (a, c, finished, progress, data) {
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
    showProgress: function (h, g, a, f, c) {
        var e = null;
        if (a) {
            e = {
                ok: _WFT("common", "common_cancel")
            };
        }
        var b = {
            title: h,
            msg: g,
            width: 300,
            progress: c,
            progressText: "<center>0&#37;</center>",
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
SYNO.SDS.RoboCopy.RunWindow = Ext.extend(SYNO.SDS.ModalWindow, {
    title: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "select_for_run"),
    owner: null,
    treePanel: null,
    startButtonId: Ext.id(),
    constructor: function (a) {
        this.owner = a.owner;
        this.caller = a.caller;
        this.preCheckFolder = a.preCheckFolder;
        SYNO.SDS.RoboCopy.RunWindow.superclass.constructor.call(this, Ext.apply(a, {
            height: 450,
            width: 300,
            layout: "fit",
            items: [this.treePanel = new SYNO.SDS.RoboCopy.SelectFolderTreePanel({
                okBtnID: this.startButtonId,
                preCheckFolder: this.preCheckFolder
            })],
            buttons: [{
                text: _T("common", "apply"),
                id: this.startButtonId,
//                cls: "syno-av-button-default",
                scope: this,
                handler: this.onClickStart
            }, {
                text: _T("common", "cancel"),
//                cls: "syno-av-button-default",
                scope: this,
                handler: this.onClickClose
            }]
        }));
    },
    onClickClose: function () {
        if (typeof (this.caller.onBeforeScanTargetSelectorWinClosed) !== "undefined" && this.caller.onBeforeScanTargetSelectorWinClosed != null) {
            this.caller.onBeforeScanTargetSelectorWinClosed();
        }
        this.close();
    },
    onClickStart: function () {
        var b = this.treePanel.getChecked();
        var a = new Array();
        for (var c = 0; c < b.length; c++) {
            a.push(b[c].realPath);
        }
        this.caller.commitRunTarget(a);
        if (typeof (this.caller.onBeforeScanTargetSelectorWinClosed) !== "undefined" && this.caller.onBeforeScanTargetSelectorWinClosed != null) {
            this.caller.onBeforeScanTargetSelectorWinClosed();
        }
        this.close();
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.ConfigWindow = Ext.extend(SYNO.SDS.ModalWindow, {
    constructor: function (cfg) {
        this.owner = cfg.owner;
        this.panel = this.createPanel(cfg);
        //
        cfg = Ext.apply({
            title: _TT("SYNO.SDS.RoboCopy.Instance", "config", "title"),
            resizable: false,
            layout: "fit",
            width: 300,
            height: 200,
            buttons: [{
                text: _T("common", "apply"),
                scope: this,
                handler: this.onClickApply
            }, {
                text: _T("common", "cancel"),
                scope: this,
                handler: this.close
            }],
            items: [this.panel]
        }, cfg);
 
        SYNO.SDS.RoboCopy.ConfigWindow.superclass.constructor.call(this, cfg);
        
//        if ((_D("usbcopy") !== "yes") && (_D("sdcopy") !== "yes")) {
//            this.panel.getForm().findField("run_after_usbcopy").disable();
//        }
    },
    createPanel: function(params) {
        var cfg = {
            padding: 20,
//            labelWidth: 150,
            border: false,
            items: [{
                xtype: "fieldset",
                title: _TT("SYNO.SDS.RoboCopy.Instance", "config", "autorun"),
                items: [{
                    synotype: "check",
                    id: "run_after_usbcopy",
                    disabled: ((_D("usbcopy", "no") === "no") && (_D("sdcopy", "no") === "no")),
                    boxLabel: _TT("SYNO.SDS.RoboCopy.Instance", "config", "run_after_usbcopy"),
                    checked: params.data.after_usbcopy
                }, {
                    synotype: "check",
                    id: "run_on_attach_disk",
                    boxLabel: _TT("SYNO.SDS.RoboCopy.Instance", "config", "run_on_attach_disk"),
                    checked: params.data.on_attach_disk
                }]
            }]
        };
        SYNO.LayoutConfig.fill(cfg);
        return new Ext.form.FormPanel(cfg);
    },
    onClickApply: function () {
        this.setStatusBusy({
            text: _T("common", "saving")
        });
        var rqst = new SYNO.SDS.RoboCopy.Request({
                url: SYNO.SDS.RoboCopy.CGI,
                params: {
                    action: "config",
                    after_usbcopy: Ext.getCmp("run_after_usbcopy").getValue(),
                    on_attach_disk: Ext.getCmp("run_on_attach_disk").getValue()
                },
                callback: function (options, success, response) {
                    this.clearStatusBusy();
                    if (success) {
                        this.close();
                    }
                    else {
                        this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
                    }
                },
                scope: this
        });
        rqst.send();
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.INFO = Ext.extend(SYNO.SDS.ModalWindow, {
    constructor: function (cfg) {
        this.owner = cfg.owner;
        this.action = (cfg.id) ? "edit" : "add";
        this.item_id = cfg.id;
        this.name = cfg.name;
//        Ext.QuickTips.init();
        var title = "";
        if (this.action === "edit") {
//            title = String.format(_TT("SYNO.SDS.RoboCopy.Instance", "ui", "edit_item"), this.name)
            title = _TT("SYNO.SDS.RoboCopy.Instance", "ui", "edit_item");
        } else {
//            title = String.format(_TT("SYNO.SDS.RoboCopy.Instance", "ui", "create_item"), "")
            title = _TT("SYNO.SDS.RoboCopy.Instance", "ui", "create_item");
        }
        this.panel = this.createPanel(cfg);
        //
        cfg = Ext.apply({
            title: title,
            resizable: false,
            layout: "fit",
            width: 550,
            height: 400,
            buttons: [{
                text: _T("common", "ok"),
                scope: this,
                handler: this.apply
            }, {
                text: _T("common", "cancel"),
                scope: this,
                handler: this.close
            }],
            items: [this.panel]
        }, cfg);
 
        SYNO.SDS.RoboCopy.INFO.superclass.constructor.call(this, cfg);
        this.mon(this.panel, "afterlayout", function (c, d) {
            SYNO.SDS.Utils.AddTip(this.panel.getForm().findField('mai_info_dest_dir').getEl(), 
                                _TT("SYNO.SDS.RoboCopy.Instance", "ui", "format_codes"));
            SYNO.SDS.Utils.AddTip(Ext.getCmp("mai_info_dest_file").getEl(), _TT("SYNO.SDS.RoboCopy.Instance", "ui", "format_codes"));
//            SYNO.SDS.Utils.AddTip(Ext.getCmp("mai_info_dest_ext").getEl(), _TT("SYNO.SDS.RoboCopy.Instance", "ui", "format_codes"));
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
            src_dir: Ext.getCmp("mai_info_src_dir").getValue(),
            src_ext: Ext.getCmp("mai_info_src_ext").getValue(),
            dest_folder: Ext.getCmp("mai_info_dest_folder").getValue(),
            dest_dir: Ext.getCmp("mai_info_dest_dir").getValue(),
            dest_file: Ext.getCmp("mai_info_dest_file").getValue(),
//            dest_ext: Ext.getCmp("mai_info_dest_ext").getValue(),
            src_remove: Ext.getCmp("mai_info_src_remove").getValue().inputValue
        };
        var rqst = new SYNO.SDS.RoboCopy.Request({
                url: SYNO.SDS.RoboCopy.CGI,
                params: request,
                callback: function (options, success, response) {
                    this.clearStatusBusy();
                    if (!success) {
                        this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
                    }
                    else {
                        this.close();
                    }
                },
                scope: this
        });
        rqst.send();
    },
    createPanel: function(params) {
        var storeShares = new Ext.data.JsonStore({
                autoLoad: true,
                baseParams: {
                    action: "shared",
                },
                url: SYNO.SDS.RoboCopy.CGI,
                fields: [ "name", "comment" ],
                root: "data"
            });
            
        var cfg = {
            padding: 20,
            labelWidth: 150,
            border: false,
            items: [{
                synotype: "number",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "priority"),
                minValue: 1,
                maxlength: 4,
                allowBlank: false,
                blankText: "Priority may be not empty",
                id: "mai_info_priority",
                value: params.priority
            },{
                synotype: "text",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "description"),
                maxlength: 255,
                id: "mai_info_description",
                width: 300,
                value: params.description
            },{
                synotype: "text",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_ext"),
                id: "mai_info_src_ext",
                value: params.src_ext
            },{
                synotype: "text",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_dir"),
                id: "mai_info_src_dir",
                width: 300,
                value: params.src_dir
            },{
                xtype: "radiogroup",
                id: "mai_info_src_remove",
                itemId: "src_remove",
                fieldLabel: "Action",
//                columns: 1,
//                vertical: true,
                items: [{
                    boxLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "action_copy"),
                    inputValue: 0,
                    name: "src_remove",
                    checked: !params.src_remove
                }, {
                    boxLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "action_move"),
                    name: "src_remove",
                    inputValue: 1,
                    checked: params.src_remove
                }]
             },{
                synotype: "combo",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_folder"),
                id: "mai_info_dest_folder",
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
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_dir"),
                id: "mai_info_dest_dir",
                width: 300,
                value: params.dest_dir,
                boxLabel: ""
            },{
                synotype: "text",
                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_file"),
                id: "mai_info_dest_file",
                width: 300,
                value: params.dest_file
//            },{
//                synotype: "text",
//                fieldLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_ext"),
//                id: "mai_info_dest_ext",
//                value: params.dest_ext
//            }, {
//                synotype: "check",
//                id: "mai_info_src_remove",
//                boxLabel: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_remove"),
//                checked: params.src_remove
            }]
        };
        SYNO.LayoutConfig.fill(cfg);
        return new Ext.form.FormPanel(cfg);
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
                action: "list",
                start: 0,
                limit: this.pageSize
            },
            url: SYNO.SDS.RoboCopy.CGI,
            fields: [
                'id', {name:'priority', type: 'int'}, 'src_dir', 'src_ext', {name:'src_remove', type: 'boolean'},
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
        this.mon(this.grid.store, "load", this.checkButtonStat, this)

        this.checkButtonStat();
        
    },
    onOpen: function (a) {
        SYNO.SDS.RoboCopy.MainWindow.superclass.onOpen.apply(this, arguments);
        return this.onRequest.call(this, a);
    },
    onRequest: function(a) {
//        this.testSend();
        if (!a || !a.fb_recs || 1 !== a.fb_recs.length || !a.fb_recs[0].get("isdir")) {
            return;
        }
        this.commitRunTarget([a.fb_recs[0].get("path")]);
        return SYNO.SDS.RoboCopy.MainWindow.superclass.onRequest.apply(this, arguments);
    },
    
    testSend: function () {
        var rqst = new SYNO.SDS.RoboCopy.Request({
                url: SYNO.SDS.RoboCopy.CGI,
                params: {
                    action: "run0",
                },
                callback: function (options, success, response) {
//                    this.clearStatusBusy();
                },
                scope: null
        });
        rqst.send();
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
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "priority_short"),
                dataIndex: "priority",
                id: "mai_grid_priority",
                sortable: true,
                width: 50
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_ext_short"),
                dataIndex: "src_ext",
                id: "mai_grid_src_ext",
                width: 50
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_dir_short"),
                dataIndex: "src_dir",
                id: "mai_grid_src_dir",
                width: 100
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "src_remove_short"),
                dataIndex: "src_remove",
                id: "mai_grid_src_remove",
                width: 50,
                renderer: function(value, metaData, record, rowIndex, colIndex, store) {
                    var action = (value ? "action_move" : "action_copy"); 
                    metaData.attr = 'ext:qtip="' + _TT("SYNO.SDS.RoboCopy.Instance", "ui", action) + '"';
                    return '<img width="16" height="16" src="' + SYNO.SDS.RoboCopy.PIC_PREFIX + action + '.png" >';
                }
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_folder_short"),
                dataIndex: 'dest_folder',
                id: "mai_grid_dest_folder",
                width: 75
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_dir_short"),
                dataIndex: 'dest_dir',
                id: "mai_grid_dest_dir",
                width: 150
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_file_short"),
                dataIndex: 'dest_file',
                id: "mai_grid_dest_file",
                width: 150
//            }, {
//                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "dest_ext_short"),
//                dataIndex: 'dest_ext',
//                id: "mai_grid_dest_ext",
//                width: 50
            }, {
                header:  _TT("SYNO.SDS.RoboCopy.Instance", "ui", "description_short"),
                dataIndex: 'description',
                id: "mai_grid_description"
            }],
            autoExpandColumn: "mai_grid_description",
            tbar: {
                items: [{
                    text: _T("common", "add"),
                    handler: this.handleAdd,
                    scope: this
                }, {
                    text: _T("common", "remove"),
                    disabled: true,
                    id: "mai_remove_button",
                    handler: this.handleRemove,
                    scope: this
                }, {
                    text: _T("common", "alt_edit"),
                    disabled: true,
                    id: "mai_edit_button",
                    handler: this.handleEdit,
                    scope: this
                }, 
                '-',
                {
                    text: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "run_now"),
                    handler: this.handleRunNow,
                    scope: this
                },
                '->',
                {
                    text: _TT("SYNO.SDS.RoboCopy.Instance", "ui", "config"),
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
            var rqst = new SYNO.SDS.RoboCopy.Request({
                    url: SYNO.SDS.RoboCopy.CGI,
                    params: {
                        action: "remove",
                        id: selected.get("id")
                    },
                    callback: function (options, success, response) {
                        this.clearStatusBusy();
                        if (!success) {
                            this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
                        }
                        this.refresh();
                    },
                    scope: this
            });
            rqst.send();
        };
        this.getMsgBox().confirm(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "ui", "remove_confirm"), callback, this);
    },
    handleRunNow: function () {
        var dlg = new SYNO.SDS.RoboCopy.RunWindow({
            owner: this.app,
            caller: this,
            preCheckFolder: []
        });
        dlg.open();
    },
    handleConfig: function() {
        this.setStatusBusy();
        var rqst = new SYNO.SDS.RoboCopy.Request({
                url: SYNO.SDS.RoboCopy.CGI,
                method: "GET",
                params: {
                    action: "config"
                },
                callback: function (options, success, response) {
                    this.clearStatusBusy();
                    if (!success) {
                        this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
                    }
                    else {
                        var cfg = {
                            owner: this,
                            data: response
                        };
                        cfg = Ext.apply(cfg, response);
                        var dlg = new SYNO.SDS.RoboCopy.ConfigWindow(cfg);
                        dlg.open();
                    }
                },
                scope: this
        });
        rqst.send();
    },
    openInfo: function (item) {
        var edt = null;
        var cfg = {
            owner: this
        };
        cfg = Ext.apply(cfg, item);
        edt = new SYNO.SDS.RoboCopy.INFO(cfg);
        this.mon(edt, "close", this.refresh, this);
        edt.open();
    },
    refresh: function () {
        this.checkButtonStat();
        this.grid.getStore().reload();
        this.grid.getView().refresh();
    },
    commitRunTarget: function (folders) {
        this.setStatusBusy();
        var rqst = new SYNO.SDS.RoboCopy.Request({
                url: SYNO.SDS.RoboCopy.CGI,
                params: {
                    action: "run",
                    folders: folders.join("|"),
                },
                callback: function (options, success, response) {
                    this.clearStatusBusy();
                    this.onRunDone(success, response, folders);
                },
                scope: this
        });
        rqst.send();
    },
    onRunDone: function (success, response, folders) {
        if (!success) {
            this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(response));
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

SYNO.SDS.RoboCopy.ErrorMessageHandler = function (result) {
    if (result && result.key) {
//        switch(result.key) {
//            case 'config_write_error':
//                return _TT("SYNO.SDS.RoboCopy.Instance", "error", "config_write_error");
//            case 'invalid_id':
//                return _TT("SYNO.SDS.RoboCopy.Instance", "error", "invalid_id");
//            case 'not_found':
//                return _TT("SYNO.SDS.RoboCopy.Instance", "error", "not_found");
//            case 'invalid_params':
//            default:
//                return _T("error", "error_unknown");
//        }
        var msg = _TT("SYNO.SDS.RoboCopy.Instance", result.sec, result.key);
        if (!msg || msg === "")
//            return result.sec + ":" + result.key; 
            return _T("error", "error_unknown");
        return msg;
    }
//    if (result && !result.success) {
////        if (result.errinfo.sec === "error" && result.errinfo.key === "config_write_error") {
////            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "config_write_error");
////        }
////        if (result.errinfo.sec === "error" && result.errinfo.key === "invalid_id") {
////            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "invalid_id");
////        }
////        if (result.errinfo.sec === "error" && result.errinfo.key === "not_found") {
////            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "not_found");
////        }
//        var msg = _TT("SYNO.SDS.RoboCopy.Instance", result.errinfo.sec, result.errinfo.key);
//        if (msg === "")
//            return _T("error", "error_unknown");
//        return msg;
//    }
    return "";
};
