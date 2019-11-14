/* Copyright (c) 2013 Synology Inc. All rights reserved. */

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.PIC_PREFIX = "3rdparty/robocopy/images/";
SYNO.SDS.RoboCopy.CGI = "/webman/3rdparty/robocopy/robocopy.cgi";

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
                            this.attachCheckChangeHandler()
                        }
                        if (c.responseText) {
                            var e = Ext.util.JSON.decode(c.responseText);
                            if (e && e.errno) {
                                this.getMsgBox().alert(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "error", "connection_error"))
                            } else {
                                for (var f = 0; f < e.length; f++) {
                                    g.childNodes[f].realPath = e[f].path;
                                    for (var d = 0; d < this.preCheckFolder.length; d++) {
                                        if (this.preCheckFolder[d] == g.childNodes[f].realPath) {
                                            g.childNodes[f].getUI().toggleCheck(true);
                                            continue
                                        }
                                        if (0 == this.preCheckFolder[d].indexOf(g.childNodes[f].realPath)) {
                                            g.childNodes[f].expand()
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
                        Ext.destroy(this.dirTree)
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
                            this.getChecked(c, f, g)
                        } else {
                            this.getMsgBox().alert(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "error", "execution_failed"))
                        }
                        break;
                    case Ext.tree.TriTreeNodeUI.CHECKSTATE:
                        g.push(!c ? f : (c == "id" ? f.id : f.attributes[c]));
                        break;
                    default:
                        break
                    }
                    f = f.nextSibling
                } while (f);
                return g
            }
        };
        Ext.apply(a, b);
        SYNO.LayoutConfig.fill(a);
        SYNO.SDS.RoboCopy.SelectFolderTreePanel.superclass.constructor.call(this, a)
    },
    attachCheckChangeHandler: function () {
        this.on("checkchange", this.checkCheckedSelection, this);
        this.fireEvent("checkchange")
    },
    checkCheckedSelection: function () {
        var a = this.getChecked();
        if (0 == a.length) {
            Ext.getCmp(this.startButtonId).disable()
        } else {
            Ext.getCmp(this.startButtonId).enable()
        }
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
        }))
    },
    onClickClose: function () {
        if (typeof (this.caller.onBeforeScanTargetSelectorWinClosed) !== "undefined" && this.caller.onBeforeScanTargetSelectorWinClosed != null) {
            this.caller.onBeforeScanTargetSelectorWinClosed()
        }
        this.close()
    },
    onClickStart: function () {
        var b = this.treePanel.getChecked();
        var a = new Array();
        for (var c = 0; c < b.length; c++) {
            a.push(b[c].realPath)
        }
        this.caller.commitRunTarget(a);
        if (typeof (this.caller.onBeforeScanTargetSelectorWinClosed) !== "undefined" && this.caller.onBeforeScanTargetSelectorWinClosed != null) {
            this.caller.onBeforeScanTargetSelectorWinClosed()
        }
        this.close()
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
        Ext.Ajax.request({
            url: SYNO.SDS.RoboCopy.CGI,
            params: request,
            scope: this,
            success: function (response, opts) {
                var obj = Ext.decode(response.responseText);
                if (obj && !obj.success) {
                    this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(obj))
                } else {
                    this.close()
                }
                this.clearStatusBusy()
            },
            failure: function (response, opts) {
                this.getMsgBox().alert(_T("error", "error_error"), _T("error", "error_unknown"));
                this.clearStatusBusy()
            }
        })
//        this.close();
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
        me = this;
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
            resizable: false,
            maximizable: false,
            minimizable: true,
            showHelp: false,
            width: 800,
            height: 500,
            layout: "fit",
            items: [this.grid],
            buttons: [{
                text: _T("common", "ok"),
                scope: this,
                handler: function () {
                    me.close()
                }
            }]
        }, cfg);
        SYNO.SDS.RoboCopy.MainWindow.superclass.constructor.call(this, cfg);
        this.mon(this.grid, "rowdblclick", this.handleEdit, this);
        this.mon(this.grid, "rowclick", this.checkButtonStat, this);
        this.mon(this.grid.store, "load", this.checkButtonStat, this)

        this.checkButtonStat();
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
        this.openInfo()
    },
    handleEdit: function () {
        var rec = null;
        if (this.grid.getSelectionModel().hasSelection()) {
            rec = this.grid.getSelectionModel().getSelections()[0]
        }
        this.openInfo(rec.json)
    },
    handleRemove: function () {
        var selected = null;
        if (this.grid.getSelectionModel().hasSelection()) {
            selected = this.grid.getSelectionModel().getSelections()[0]
        } else {
            return
        }
        var callback = function (btnID, text, opt) {
            if ("yes" !== btnID) {
                return
            }
            this.setStatusBusy();
            Ext.Ajax.request({
                url: SYNO.SDS.RoboCopy.CGI,
                params: {
                    action: "remove",
                    id: selected.get("id")
                },
                scope: this,
            success: function (response, opts) {
                var obj = Ext.decode(response.responseText);
                    if (obj && !obj.success) {
                        this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(obj))
                    }
                    this.clearStatusBusy();
                    this.refresh()
                },
                failure: function (response, opts) {
                    this.getMsgBox().alert(_T("error", "error_error"), _T("error", "error_unknown"));
                    this.clearStatusBusy();
                    this.refresh()
                }
            })
        };
        this.getMsgBox().confirm(this.title, _TT("SYNO.SDS.RoboCopy.Instance", "ui", "remove_confirm"), callback, this)
    },
    handleRunNow: function () {
        var dlg = new SYNO.SDS.RoboCopy.RunWindow({
            owner: this.app,
            caller: this,
            preCheckFolder: []
        });
        dlg.open()
    },
    openInfo: function (item) {
        var edt = null;
        var cfg = {
            owner: this
        };
        cfg = Ext.apply(cfg, item);
        edt = new SYNO.SDS.RoboCopy.INFO(cfg);
        this.mon(edt, "close", this.refresh, this);
        edt.open()
    },
    refresh: function () {
        this.checkButtonStat();
        this.grid.getStore().reload();
        this.grid.getView().refresh()
    },
    commitRunTarget: function (a) {
//        this.getMsgBox().alert("RUN", a)
        this.setStatusBusy();
        Ext.Ajax.request({
            url: SYNO.SDS.RoboCopy.CGI,
            params: {
                    action: "run",
                    folders: a.join("|")
                },
                scope: this,
            success: function (response, opts) {
                this.clearStatusBusy();
                var obj = Ext.decode(response.responseText);
                if (obj && !obj.success) {
                    this.getMsgBox().alert(_T("error", "error_error"), SYNO.SDS.RoboCopy.ErrorMessageHandler(obj))
                }
//                this.refresh()
            },
            failure: function (response, opts) {
                this.clearStatusBusy();
                this.getMsgBox().alert(_T("error", "error_error"), _T("error", "error_unknown"));
//                this.refresh()
            }
        })
    }
});

SYNO.SDS.RoboCopy.ErrorMessageHandler = function (result) {
    if (result && !result.success) {
        if (result.errinfo.sec == "error" && result.errinfo.key == "config_write_error") {
            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "config_write_error")
        }
        if (result.errinfo.sec == "error" && result.errinfo.key == "invalid_id") {
            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "invalid_id")
        }
        if (result.errinfo.sec == "error" && result.errinfo.key == "not_found") {
            return _TT("SYNO.SDS.RoboCopy.Instance", "error", "not_found")
        }
        return _T("error", "error_unknown")
    }
    return ""
};
