/* Copyright (c) 2013-2021 Vitaly Shpachenko. All rights reserved. */

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.MetadataEditorApp = Ext.extend(SYNO.SDS.AppInstance, {
    appWindowName: "SYNO.SDS.RoboCopy.MetadataEditorWindow",
    constructor: function() {
        SYNO.SDS.RoboCopy.MetadataEditorApp.superclass.constructor.apply(this, arguments);
    }
});

Ext.ns("SYNO.SDS.RoboCopy");
SYNO.SDS.RoboCopy.MetadataEditorWindow = Ext.extend(SYNO.SDS.AppWindow, {
    constructor: function(args) {
        var cfg = this.fillConfig();
        _DEBUG("SYNO.SDS.RoboCopy.MetadataEditorWindow.constructor", args);
        SYNO.SDS.RoboCopy.MetadataEditorWindow.superclass.constructor.call(this, Ext.apply(cfg, args));
        // this.mon(this, "afterlayout", this.onLoadData, this, {
            // single: true
        // })
    },
    fillConfig: function() {
        Ext.apply(this);
        var a = {
            owner: this.owner,
            pinable: false,
            padding: 10,
            width: 530,
            autoHeight: true,
            collapsible: false,
            resizable: false,
            showHelp: false,
            maximizable: false,
            minimizable: false,
            title: _RC_STR("editor", "window_title"),
            buttons: [{
                btnStyle: "blue",
                itemId: "submit_button",
                text: _T("common", "commit"),
                handler: this.onConfirm,
                scope: this
            }, {
                text: _T("common", "cancel"),
                handler: this.close,
                scope: this
            }],
            items: this.initPanel()
        };
        return a
    },
    initPanel: function() {
        var cfg = {
            padding: 20,
//             autoFlexcroll: true,
            autoHeight: true,
            border: false,
            items: [{
                xtype: getXType("syne_checkbox", "checkbox"),
                boxLabel: _RC_STR("editor", "set_date"),
                name: "set_date",
                hideLabel: true,
                listeners: {
                    scope: this,
                    check: function(chkbox, checked) {
                        this.setFldEnabled("date", checked);
                    }
                }
            },{
                xtype: getXType("syno_datefield", "datefield"),
                fieldLabel: _RC_STR("editor", "date"),
                synotype: "indent",
                indent: 1,
                name: "date",
                width: 150,
                labelWidth: 150,
                format: "Y-m-d",
                allowBlank: false,
                editable: false,
                disabled: true,
                maxValue: "2037/12/31",
                minValue: "1900/1/1"
            },{
                xtype: getXType("syne_checkbox", "checkbox"),
                boxLabel: _RC_STR("editor", "set_location"),
                name: "set_location",
                hideLabel: true,
                listeners: {
                    scope: this,
                    check: function(chkbox, checked) {
                        this.setFldEnabled("location", checked);
                    }
                }
            },{
                xtype: getXType("syno_textfield", "textfield"),
                fieldLabel: _RC_STR("editor", "location"),
                synotype: "indent",
                indent: 1,
                name: "location",
                width: 300,
//                allowBlank: false,
                labelWidth: 150,
                disabled: true,
                maxlength: 255
            },{
                xtype: getXType("syne_checkbox", "checkbox"),
                boxLabel: _RC_STR("editor", "set_title"),
                name: "set_title",
                hideLabel: true,
                listeners: {
                    scope: this,
                    check: function(chkbox, checked) {
                        this.setFldEnabled("title", checked);
                    }
                }
            },{
                xtype: getXType("syno_textfield", "textfield"),
                fieldLabel: _RC_STR("editor", "title"),
                synotype: "indent",
                indent: 1,
                name: "title",
                width: 300,
//                allowBlank: false,
                labelWidth: 150,
                disabled: true,
                maxlength: 255
            }]
        };
        SYNO.LayoutConfig.fill(cfg);
        var pnl = new Ext.form.FormPanel(cfg);
        this.panel = pnl;
        return pnl;
    },
    setFldEnabled: function(fld, val) {
        var frm = this.panel.getForm();
        if (val) {
            frm.findField(fld).enable();
        } else {
            frm.findField(fld).disable();
        }
    },
    onOpen: function(a) {
//        _DEBUG("SYNO.SDS.RoboCopy.MetadataEditorWindow.onOpen", a);
        SYNO.SDS.RoboCopy.MetadataEditorWindow.superclass.onOpen.apply(this, arguments);
        return this.onRequest(a)
    },
    onRequest: function(d) {
        _DEBUG("SYNO.SDS.RoboCopy.MetadataEditorWindow.onRequest", d);
        SYNO.SDS.RoboCopy.MetadataEditorWindow.superclass.onRequest.apply(this, arguments);
        var a, f, e, b, c;
//         , g = SYNO.SDS.Utils.GetLocalizedString(this.jsConfig.title);
//         _DEBUG("onRequest");
        // _DEBUG(d);
        if (!d || !d.fb_recs) {
            return;
        }
        var files = SYNO.SDS.RoboCopy.utils.filterSelection(d.fb_recs, false);
//         _DEBUG(files);
        this.files = files || [];
        if (!files || (files.length == 0)) {
            return;
        }
        this.setStatusBusy();
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            params: {
                action: "fileinfo",
                files: files.join("|"),
            },
            callback: function(a, c, b) {
                this.clearStatusBusy();
                if (!b.success) {
                    this.getMsgBox().alert(this.title, 
                        SYNO.SDS.RoboCopy.GetErrorMessage(b.errinfo, "editor"));
                    return
                }
                this.panel.getForm().setValues(b.data);
            },
            scope: this
        }).start(true)
    },
    onConfirm: function() {
        var frm = this.panel.getForm();
        if (!frm.isValid()) {
            return;
        }
        if (!frm.isDirty()) {
            this.close();
            return
        }
        var params = {};
        var f = frm.findField("set_date");
        if (frm.findField("set_date").getValue()) {
            f = frm.findField("date");
            Ext.apply(params, {
                date: frm.findField("date").getValue().format('Y-m-d')
            });
        }
        f = frm.findField("set_location");
        if (frm.findField("set_location").getValue()) {
            f = frm.findField("location");
            Ext.apply(params, {
                location: frm.findField("location").getValue()
            });
        }
        f = frm.findField("set_title");
        if (frm.findField("set_title").getValue()) {
            f = frm.findField("title");
            Ext.apply(params, {
                title: frm.findField("title").getValue()
            });
        }

        this.setStatusBusy();
        this.addAjaxTask({
            single: true,
            autoJsonDecode: true,
            url: SYNO.SDS.RoboCopy.CGI,
            method: "POST",
            params: Ext.apply(params, {
                action: "fileinfo",
                files: this.files.join("|"),
            }),
            callback: function(a, c, b) {
                this.clearStatusBusy();
                if (!b.success) {
                    this.getMsgBox().alert(this.title, 
                        SYNO.SDS.RoboCopy.GetErrorMessage(b.errinfo, "editor"));
                    return
                }
                this.close();
            },
            scope: this
        }).start(true)
    },
});
