local TS = Talksmith

function TS.Editor.Open()
    if IsValid(TS.Editor.Frame) then
        TS.Editor.Frame:Remove()
    end
    local T = TS.Editor.Theme

    local f = vgui.Create("EditablePanel")
    TS.Editor.Frame = f
    f:SetSize(math.min(math.max(ScrW() * 0.94, 760), ScrW()), math.min(math.max(ScrH() * 0.92, 520), ScrH()))
    f:Center()
    f:MakePopup()
    f.Paint = function(_, w, h)
        surface.SetDrawColor(T.bar)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local doc, dirty = nil, false
    local activeExampleDraft = nil
    local history = TS.Editor.NewHistory(100)
    local sel = { node = nil, opt = nil }
    local issues = {}
    local canvas, inspector, listPanel, problems, statusbar, titlebar, toolbar

    local function snapshot()
        if doc then
            history:Push(doc)
        end
    end

    titlebar = f:Add("DPanel")
    titlebar:Dock(TOP)
    titlebar:SetTall(54)
    titlebar:DockPadding(14, 0, 6, 0)
    titlebar.Paint = function(_, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
        draw.SimpleText(
            TS.L("workflow"),
            "Talksmith_E_Tiny",
            16,
            15,
            T.blue,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(TS.L("editor"), "Talksmith_E_Title", 16, 36, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if doc then
            draw.SimpleText(
                doc.meta.title or doc.id,
                "Talksmith_E_Head",
                w / 2,
                20,
                T.text,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
            local status = activeExampleDraft
                    and (doc.id .. "  ·  " .. TS.L("preset_draft") .. "  ·  ● " .. TS.L("status_changed"))
                or (doc.id
                    .. "  ·  "
                    .. TS.L("revision")
                    .. " "
                    .. (doc.meta.revision or 0)
                    .. "  ·  "
                    .. (dirty and ("● " .. TS.L("status_changed")) or TS.L("status_saved")))
            draw.SimpleText(
                status,
                "Talksmith_E_Tiny",
                w / 2,
                39,
                dirty and T.yellow or T.dim,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )
        end
    end

    local function reallyClose()
        f:Remove()
    end
    local function confirmIfDirty(fn)
        if dirty and activeExampleDraft then
            fn()
            return
        end
        if dirty then
            TS.Editor.Confirm(TS.L("unsaved_title"), TS.L("unsaved_text"), {
                { label = TS.L("discard"), callback = fn, danger = true },
                { label = TS.L("cancel"), quiet = true },
            })
        else
            fn()
        end
    end

    local closeBtn = titlebar:Add("DButton")
    closeBtn:Dock(RIGHT)
    closeBtn:SetWide(38)
    closeBtn:DockMargin(0, 10, 6, 10)
    TS.Editor.StyleButton(closeBtn, { label = "✕", quiet = true })
    closeBtn.DoClick = function()
        confirmIfDirty(reallyClose)
    end

    toolbar = f:Add("DPanel")
    toolbar:Dock(TOP)
    toolbar:SetTall(46)
    local veryNarrow = f:GetWide() < 700
    toolbar:DockPadding(veryNarrow and 4 or 10, 8, veryNarrow and 4 or 10, 8)
    toolbar.Paint = function(_, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local function tbtn(label, wide, fn, opts)
        opts = opts or {}
        local b = toolbar:Add("DButton")
        b:Dock(LEFT)
        surface.SetFont(opts.font or "Talksmith_E_Body")
        local tw = surface.GetTextSize(label or "")
        local hasIcon = opts.icon and opts.icon ~= ""
        local pad = veryNarrow and 18 or 26
        local needed = tw + (hasIcon and 25 or 0) + pad
        b:SetWide(math.max(veryNarrow and 36 or 44, math.ceil(needed)))
        b:DockMargin(0, 0, veryNarrow and 2 or (f:GetWide() < 1050 and 4 or 8), 0)
        TS.Editor.StyleButton(b, table.Merge({ label = label, quiet = true }, opts))
        TS.Editor.SetTooltip(b, label)
        b.DoClick = fn
        return b
    end
    local function tsep()
        local s = toolbar:Add("DPanel")
        s:Dock(LEFT)
        s:SetWide(1)
        s:DockMargin(veryNarrow and 1 or 2, 2, veryNarrow and 1 or 10, 2)
        s.Paint = function(_, w, h)
            surface.SetDrawColor(T.lineSoft)
            surface.DrawRect(0, 0, w, h)
        end
    end

    local body = f:Add("DPanel")
    body:Dock(FILL)
    body.Paint = function() end

    local refreshProblems, scheduleProblemsRefresh, setDocument, saveDoc

    listPanel = TS.Editor.BuildDialogueList(body, {
        OnOpen = function(id, isDraft)
            if doc and doc.id == id then
                return
            end
            confirmIfDirty(function()
                if isDraft then
                    local draft = TS.Editor.ExampleDrafts[id]
                    if draft then
                        setDocument(draft, true, id)
                    end
                else
                    TS.Editor.RequestDocuments(id)
                end
            end)
        end,
        OnNew = function()
            confirmIfDirty(function()
                TS.Editor.StringRequest(TS.L("new"), TS.L("rename_prompt"), "my_dialogue", function(txt)
                    local id = TS.Utils.SafeID(txt or "")
                    if not id then
                        TS.Runtime.Notify(TS.L("save_failed", "bad_id"), NOTIFY_ERROR, 3)
                        return
                    end
                    local d = TS.Dialogues.New(id, LocalPlayer():SteamID64())
                    setDocument(d, true)
                end, nil, TS.L("new"), TS.L("cancel"))
            end)
        end,
        OnRename = function(id)
            local function prompt()
                TS.Editor.StringRequest(TS.L("rename"), TS.L("rename_prompt"), id, function(txt)
                    local newid = TS.Utils.SafeID(txt or "")
                    if not newid or newid == id then
                        return
                    end
                    TS.Editor.Manage("rename", id, newid)
                    if doc and doc.id == id then
                        doc = nil
                        dirty = false
                        canvas:SetDocument(nil)
                        TS.Editor.BuildInspector(inspector, nil, nil, {})
                        timer.Simple(0.3, function()
                            if IsValid(f) then
                                TS.Editor.RequestDocuments(newid)
                            end
                        end)
                    end
                end, nil, TS.L("rename"), TS.L("cancel"))
            end
            if doc and doc.id == id then
                confirmIfDirty(prompt)
            else
                prompt()
            end
        end,
        OnDuplicate = function(id)
            TS.Editor.Manage("duplicate", id)
        end,
        OnImport = function()
            confirmIfDirty(function()
                TS.Editor.OpenPresetImporter(function(imported)
                    setDocument(imported, true)
                end)
            end)
        end,
        OnExport = function(id)
            TS.Editor.RequestExport(id)
        end,
        OnDelete = function(id, title)
            TS.Editor.Confirm(TS.L("delete"), TS.L("delete_confirm", title), {
                {
                    label = TS.L("delete"),
                    danger = true,
                    callback = function()
                        TS.Editor.Manage("delete", id)
                        if doc and doc.id == id then
                            doc = nil
                            dirty = false
                            canvas:SetDocument(nil)
                            TS.Editor.BuildInspector(inspector, nil, nil, {})
                        end
                    end,
                },
                { label = TS.L("cancel"), quiet = true },
            })
        end,
        OnDeleteDraft = function(id, title)
            TS.Editor.Confirm(TS.L("preset_remove_title"), TS.L("preset_remove_text", title), {
                {
                    label = TS.L("delete"),
                    danger = true,
                    callback = function()
                        if activeExampleDraft == id then
                            setDocument(nil, false)
                        end
                        TS.Editor.RemoveExampleDraft(id)
                    end,
                },
                { label = TS.L("cancel"), quiet = true },
            })
        end,
    })
    listPanel:SetDrafts(TS.Editor.ExampleDrafts)
    listPanel:SetWide(math.Clamp(f:GetWide() * 0.19, 190, 250))

    local right = body:Add("DPanel")
    right:Dock(RIGHT)
    right:SetWide(math.Clamp(f:GetWide() * 0.24, 280, 400))
    right.Paint = function(_, w, h)
        surface.SetDrawColor(T.side)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, 0, h)
    end
    inspector = right:Add("DScrollPanel")
    inspector:Dock(FILL)
    inspector:DockMargin(16, 14, 16, 14)
    local ibar = inspector:GetVBar()
    ibar:SetWide(4)
    ibar:SetHideButtons(true)
    ibar.Paint = function() end
    ibar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(2, 0, 0, w, h, T.line)
    end

    local center = body:Add("DPanel")
    center:Dock(FILL)
    center.Paint = function() end

    statusbar = center:Add("DPanel")
    statusbar:Dock(BOTTOM)
    statusbar:SetTall(30)
    problems = TS.Editor.BuildProblems(center, {
        OnFocusNode = function(id)
            canvas:CenterOn(id)
            sel.node, sel.opt = id, nil
            sel.uiNode, sel.tab, sel.inspectorOpen = nil, "line", {}
            TS.Editor.BuildInspector(inspector, doc, sel, canvas.InspectorCB)
        end,
    })
    canvas = center:Add("TalksmithCanvas")
    canvas:Dock(FILL)

    local errCount, warnCount = 0, 0
    local problemRefreshVersion = 0
    refreshProblems = function()
        problemRefreshVersion = problemRefreshVersion + 1
        if not doc then
            issues = {}
            errCount, warnCount = 0, 0
            problems:SetIssues({})
            canvas:SetErrors({})
            return
        end
        local _, list, e, w = TS.Editor.ProblemSummary(doc)
        issues = list
        errCount, warnCount = e, w
        problems:SetIssues(list)
        canvas:SetErrors(TS.Editor.ProblemNodeMap(list))
    end

    scheduleProblemsRefresh = function()
        problemRefreshVersion = problemRefreshVersion + 1
        local version = problemRefreshVersion
        timer.Simple(0.12, function()
            if not IsValid(f) or TS.Editor.Frame ~= f or problemRefreshVersion ~= version then
                return
            end
            refreshProblems()
        end)
    end

    local function changed()
        dirty = true
        if activeExampleDraft and doc then
            doc.meta.modified = os.time()
            TS.Editor.ExampleDrafts[activeExampleDraft] = doc
            listPanel:SetDrafts(TS.Editor.ExampleDrafts)
        end
        listPanel:SetActive(doc and doc.id, dirty)
        canvas:InvalidateGraphStats()
        scheduleProblemsRefresh()
    end

    local inspectorCB
    inspectorCB = {
        Changed = changed,
        Snapshot = snapshot,
        SelectOpt = function(i)
            sel.opt = i
            sel.tab = "answers"
            canvas.SelOpt = i
            inspector:GetVBar():SetScroll(0)
            TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
        end,
        AddNode = function()
            if doc then
                canvas:AddNode()
            end
        end,
    }
    canvas.InspectorCB = inspectorCB

    function f:RefreshCatalogInspector()
        if TS.Editor.Frame ~= self or not IsValid(inspector) then
            return
        end

        local bar = inspector:GetVBar()
        local savedScroll = IsValid(bar) and bar:GetScroll() or 0
        refreshProblems()
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)

        timer.Simple(0, function()
            if TS.Editor.Frame ~= f or not IsValid(inspector) then
                return
            end
            inspector:InvalidateLayout(true)
            local currentBar = inspector:GetVBar()
            if IsValid(currentBar) then
                currentBar:SetScroll(savedScroll)
                inspector:InvalidateLayout(true)
            end
        end)
    end

    canvas.OnSelection = function(_, id, opt)
        if sel.node ~= id then
            sel.uiNode, sel.tab, sel.inspectorOpen = nil, opt and "answers" or "line", {}
        elseif opt then
            sel.tab = "answers"
        end
        sel.node, sel.opt = id, opt
        inspector:GetVBar():SetScroll(0)
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
    end
    canvas.OnGraphChanged = function()
        changed()
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
    end
    canvas.Snapshot = snapshot

    local function applyHistory(newDoc)
        if not newDoc then
            return
        end
        doc = newDoc
        TS.Editor.Document = doc
        canvas.Doc = doc
        canvas:InvalidateGraphStats()
        sel.opt = nil
        if sel.node and not doc.nodes[sel.node] then
            sel.node = nil
        end
        dirty = true
        if activeExampleDraft then
            TS.Editor.ExampleDrafts[activeExampleDraft] = doc
            listPanel:SetDrafts(TS.Editor.ExampleDrafts)
        end
        listPanel:SetActive(doc.id, dirty)
        refreshProblems()
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
    end
    canvas.OnUndo = function()
        applyHistory(history:Undo(doc))
    end
    canvas.OnRedo = function()
        applyHistory(history:Redo(doc))
    end

    setDocument = function(d, markDirty, exampleDraftID)
        doc = d
        activeExampleDraft = exampleDraftID
        TS.Editor.Document = d
        history = TS.Editor.NewHistory(100)
        sel = { node = nil, opt = nil }
        dirty = markDirty and true or false
        canvas:SetDocument(d)
        listPanel:SetDrafts(TS.Editor.ExampleDrafts)
        listPanel:SetActive(d and d.id, dirty)
        refreshProblems()
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
    end

    saveDoc = function()
        if not doc then
            return
        end
        local ok = TS.Editor.ProblemSummary(doc)
        if not ok then
            problems:SetExpanded(true)
            refreshProblems()
            TS.Runtime.Notify(TS.L("fix_errors"), NOTIFY_ERROR, 4)
            return
        end
        TS.Editor.Save(doc)
    end
    canvas.OnSave = saveDoc

    local saveBtn = tbtn(TS.L("save"), 100, saveDoc, { accent = true, quiet = false, icon = "floppy-disk" })
    TS.Editor.SetTooltip(saveBtn, TS.L("save") .. "  (Ctrl+S)")
    saveBtn.Think = function(s)
        s:SetDisabled(not doc or not dirty)
    end
    tsep()
    local undoBtn = tbtn(TS.L("undo"), 90, function()
        canvas.OnUndo()
    end, { icon = "arrow-counter-clockwise" })
    TS.Editor.SetTooltip(undoBtn, TS.L("undo") .. "  (Ctrl+Z)")
    undoBtn.Think = function(s)
        s:SetDisabled(#history.undo == 0)
    end
    local redoBtn = tbtn(TS.L("redo"), 90, function()
        canvas.OnRedo()
    end, { icon = "arrow-clockwise" })
    TS.Editor.SetTooltip(redoBtn, TS.L("redo") .. "  (Ctrl+Y)")
    redoBtn.Think = function(s)
        s:SetDisabled(#history.redo == 0)
    end
    tsep()
    local addNodeBtn = tbtn(TS.L("node"), 96, function()
        if doc then
            canvas:AddNode()
        end
    end, { quiet = false, icon = "plus" })
    TS.Editor.SetTooltip(addNodeBtn, TS.L("add_node_here"))
    addNodeBtn.Think = function(s)
        s:SetDisabled(not doc)
    end
    local previewBtn = tbtn(TS.L("preview"), 122, function()
        if doc then
            TS.Editor.Preview(doc)
        end
    end, { icon = "play" })
    TS.Editor.SetTooltip(previewBtn, TS.L("preview_hint"))
    previewBtn.Think = function(s)
        s:SetDisabled(not doc)
    end
    tsep()

    local toolsBtn = tbtn(TS.L("tools") .. " ▾", 112, function() end)
    toolsBtn.DoClick = function()
        local m = TS.Editor.CreateMenu(290)
        TS.Editor.AddMenuOption(m, TS.L("settings_title"), function()
            if doc then
                TS.Editor.OpenDialogueSettings(doc, { Changed = changed, Snapshot = snapshot })
            end
        end, { icon = "gear-six", enabled = doc ~= nil, accent = true })
        TS.Editor.AddMenuSpacer(m)
        TS.Editor.AddMenuOption(m, TS.L("actor_place"), function()
            if doc then
                TS.Editor.ManageActor("place", doc.id)
            end
        end, { icon = "user-plus", enabled = doc ~= nil })
        TS.Editor.AddMenuOption(m, TS.L("actor_update"), function()
            if doc then
                TS.Editor.ManageActor("update", doc.id)
            end
        end, { icon = "user-focus", enabled = doc ~= nil })
        TS.Editor.AddMenuOption(m, TS.L("copy_aim_transform"), function()
            if doc then
                TS.Editor.ManageActor("copy_aim", doc.id)
            end
        end, { icon = "crosshair-simple", enabled = doc ~= nil })
        TS.Editor.AddMenuOption(m, TS.L("actor_delete"), function()
            TS.Editor.ManageActor("remove")
        end, { icon = "user-minus", danger = true })
        local integrations = TS.Editor.Catalog and TS.Editor.Catalog.integrations
        local vj = integrations and integrations.vj
        if vj and vj.enabled == true and vj.status == "available" then
            TS.Editor.AddMenuSpacer(m)
            TS.Editor.AddMenuOption(m, TS.L("vj_bind"), function()
                if doc then TS.Editor.ManageActor("vj_bind", doc.id) end
            end, { icon = "user-focus", enabled = doc ~= nil })
            TS.Editor.AddMenuOption(m, TS.L("vj_bind_native"), function()
                if doc then TS.Editor.ManageActor("vj_bind", doc.id, "native") end
            end, { icon = "user-focus", enabled = doc ~= nil })
            TS.Editor.AddMenuOption(m, TS.L("vj_unbind"), function()
                TS.Editor.ManageActor("vj_unbind")
            end, { icon = "user-minus" })
        end
        TS.Editor.AddMenuSpacer(m)
        TS.Editor.AddMenuOption(m, TS.L("actor_save"), function()
            TS.Editor.ManageActor("save")
        end, { icon = "floppy-disk" })
        TS.Editor.AddMenuOption(m, TS.L("actor_load"), function()
            TS.Editor.ManageActor("load")
        end, { icon = "folder-open" })
        m:Open()
    end
    TS.Editor.SetTooltip(toolsBtn, TS.L("settings_title") .. " · " .. TS.L("actor_menu"))

    local helpBtn = toolbar:Add("DButton")
    helpBtn:Dock(RIGHT)
    surface.SetFont("Talksmith_E_Body")
    helpBtn:SetWide(math.ceil(surface.GetTextSize(TS.L("help")) + 25 + 26))
    helpBtn:DockMargin(8, 0, 0, 0)
    TS.Editor.StyleButton(helpBtn, { label = TS.L("help"), quiet = true, icon = "question" })
    helpBtn.DoClick = function()
        TS.Editor.OpenHelp()
    end
    TS.Editor.SetTooltip(helpBtn, TS.L("help_title"))

    local presetsBtn = toolbar:Add("DButton")
    presetsBtn:Dock(RIGHT)
    surface.SetFont("Talksmith_E_Body")
    presetsBtn:SetWide(math.ceil(surface.GetTextSize(TS.L("presets")) + 25 + 26))
    presetsBtn:DockMargin(8, 0, 0, 0)
    TS.Editor.StyleButton(presetsBtn, { label = TS.L("presets"), quiet = true, icon = "clipboard-text" })
    presetsBtn.DoClick = function()
        TS.Editor.OpenExamples()
    end
    TS.Editor.SetTooltip(presetsBtn, TS.L("presets_title"))

    local addonSettingsBtn = toolbar:Add("DButton")
    addonSettingsBtn:Dock(RIGHT)
    surface.SetFont("Talksmith_E_Body")
    addonSettingsBtn:SetWide(math.ceil(surface.GetTextSize(TS.L("addon_settings")) + 25 + 26))
    addonSettingsBtn:DockMargin(8, 0, 0, 0)
    TS.Editor.StyleButton(addonSettingsBtn, {
        label = TS.L("addon_settings"),
        quiet = true,
        icon = "gear-six",
    })
    addonSettingsBtn.DoClick = function()
        TS.Editor.OpenSettings()
    end
    TS.Editor.SetTooltip(addonSettingsBtn, TS.L("addon_settings_title"))

    statusbar.Paint = function(_, w, h)
        surface.SetDrawColor(T.bar)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(T.line)
        surface.DrawLine(0, 0, w, 0)
        if doc then
            local nodeCount, connectionCount = canvas:GraphStats()
            draw.SimpleText(
                TS.L("nodes")
                    .. ": "
                    .. nodeCount
                    .. "    "
                    .. TS.L("links")
                    .. ": "
                    .. connectionCount,
                "Talksmith_E_Small",
                12,
                h / 2,
                T.muted,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end
    end
    local probBtn = statusbar:Add("DButton")
    probBtn:Dock(RIGHT)
    probBtn:SetWide(184)
    probBtn:SetText("")
    probBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            surface.SetDrawColor(T.hover)
            surface.DrawRect(0, 0, w, h)
        end
        local cy = h / 2
        surface.SetFont("Talksmith_E_Small")
        if errCount == 0 and warnCount == 0 then
            local label = TS.L("validation_ok")
            draw.SimpleText(label, "Talksmith_E_Small", w - 10, cy, T.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            local tw = surface.GetTextSize(label)
            TS.Editor.DrawIcon("check", w - 10 - tw - 20, cy - 7, 14, T.green)
        else
            local x = w - 10
            local wc = tostring(warnCount)
            draw.SimpleText(wc, "Talksmith_E_Small", x, cy, warnCount > 0 and T.yellow or T.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            x = x - surface.GetTextSize(wc) - 5
            TS.Editor.DrawIcon("warning", x - 14, cy - 7, 14, warnCount > 0 and T.yellow or T.dim)
            x = x - 14 - 14
            local ec = tostring(errCount)
            draw.SimpleText(ec, "Talksmith_E_Small", x, cy, errCount > 0 and T.red or T.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            x = x - surface.GetTextSize(ec) - 5
            TS.Editor.DrawIcon("x-circle", x - 14, cy - 7, 14, errCount > 0 and T.red or T.dim)
        end
    end
    TS.Editor.SetTooltip(probBtn, TS.L("problems"))
    probBtn.Think = function(s)
        s:SetVisible(doc ~= nil)
        s:SetWide(statusbar:GetWide() < 520 and 112 or 184)
    end
    probBtn.DoClick = function()
        problems:SetExpanded(not problems.expanded)
    end

    local zoomGroup = statusbar:Add("DPanel")
    zoomGroup:Dock(RIGHT)
    zoomGroup:SetWide(142)
    zoomGroup:DockMargin(0, 2, 4, 2)
    zoomGroup.Paint = function() end
    zoomGroup.Think = function(s)
        s:SetVisible(doc ~= nil and statusbar:GetWide() >= 420)
    end
    local function statusZoomButton(label, wide, tip, fn, icon)
        local b = zoomGroup:Add("DButton")
        b:Dock(LEFT)
        b:SetWide(wide)
        TS.Editor.StyleButton(b, { label = label, quiet = true, font = "Talksmith_E_Small", icon = icon, iconSize = 15 })
        TS.Editor.SetTooltip(b, tip or label)
        b.DoClick = fn
        return b
    end
    statusZoomButton("", 28, TS.L("zoom_out"), function()
        canvas:OnMouseWheeled(-1)
    end, "minus")
    local zoomLabel = zoomGroup:Add("DLabel")
    zoomLabel:Dock(LEFT)
    zoomLabel:SetWide(48)
    zoomLabel:SetFont("Talksmith_E_Tiny")
    zoomLabel:SetTextColor(T.muted)
    zoomLabel:SetContentAlignment(5)
    zoomLabel.Think = function(s)
        s:SetText(math.Round(canvas.Zoom * 100) .. "%")
    end
    statusZoomButton("", 28, TS.L("zoom_in"), function()
        canvas:OnMouseWheeled(1)
    end, "plus")
    statusZoomButton("", 34, TS.L("center_start"), function()
        canvas:CenterStart()
    end, "crosshair")

    local receiveList = function(list)
        if not IsValid(f) or TS.Editor.Frame ~= f then
            return
        end
        TS.Editor.DocumentList = istable(list) and list or {}
        listPanel:SetDocuments(TS.Editor.DocumentList)
        listPanel:SetDrafts(TS.Editor.ExampleDrafts)
        listPanel:SetActive(doc and doc.id, dirty)
    end
    TS.Editor.ReceiveList = receiveList

    local receiveDoc = function(d)
        if not IsValid(f) or TS.Editor.Frame ~= f then
            return
        end
        setDocument(d, false)
    end
    TS.Editor.ReceiveDocument = receiveDoc

    local saveResult = function(ok, result, resIssues)
        if not IsValid(f) or TS.Editor.Frame ~= f then
            return
        end
        if ok then
            if activeExampleDraft then
                local savedDraft = activeExampleDraft
                activeExampleDraft = nil
                TS.Editor.RemoveExampleDraft(savedDraft)
            end
            dirty = false
            if doc then
                doc.meta.revision = tonumber(result) or doc.meta.revision
            end
            listPanel:SetActive(doc and doc.id, false)
            TS.Runtime.Notify(TS.L("saved", result), NOTIFY_GENERIC, 3)
        elseif result == "revision_conflict" and doc then
            TS.Editor.Confirm(TS.L("conflict_title"), TS.L("conflict_text"), {
                {
                    label = TS.L("conflict_reload"),
                    accent = true,
                    callback = function()
                        TS.Editor.RequestDocuments(doc.id)
                    end,
                },
                {
                    label = TS.L("conflict_copy"),
                    callback = function()
                        doc.id = string.sub(doc.id, 1, 48) .. "_copy" .. math.random(100, 999)
                        doc.meta.revision = 0
                        TS.Editor.Save(doc)
                        listPanel:SetActive(doc.id, true)
                    end,
                },
                { label = TS.L("cancel"), quiet = true },
            })
        else
            if istable(resIssues) and #resIssues > 0 then
                problems:SetIssues(resIssues)
                problems:SetExpanded(true)
            end
            TS.Runtime.Notify(TS.L("save_failed", result), NOTIFY_ERROR, 5)
        end
    end
    TS.Editor.SaveResult = saveResult

    function f:CaptureState()
        return {
            doc = doc,
            dirty = dirty,
            exampleDraft = activeExampleDraft,
            history = history,
            selection = TS.Utils.Copy(sel or {}),
            canvasSelection = TS.Utils.Copy(canvas and canvas.Sel or {}),
            canvasPrimary = canvas and canvas.Primary,
            canvasSelOpt = canvas and canvas.SelOpt,
            inspectorScroll = IsValid(inspector) and inspector:GetVBar():GetScroll() or 0,
            node = sel and sel.node,
            opt = sel and sel.opt,
            zoom = canvas and canvas.Zoom,
            ox = canvas and canvas.OX,
            oy = canvas and canvas.OY,
        }
    end

    function f:RestoreState(state)
        if not istable(state) or not state.doc then
            return
        end
        setDocument(state.doc, state.dirty, state.exampleDraft)
        history = state.history or history
        sel = istable(state.selection) and TS.Utils.Copy(state.selection) or { node = state.node, opt = state.opt }
        if canvas then
            canvas.Sel = istable(state.canvasSelection) and TS.Utils.Copy(state.canvasSelection) or {}
            canvas.Primary = state.canvasPrimary or sel.node
            canvas.SelOpt = state.canvasSelOpt or sel.opt
            if state.zoom then canvas.Zoom = state.zoom end
            if state.ox then canvas.OX = state.ox end
            if state.oy then canvas.OY = state.oy end
        end
        refreshProblems()
        TS.Editor.BuildInspector(inspector, doc, sel, inspectorCB)
        timer.Simple(0, function()
            if not IsValid(inspector) then
                return
            end
            inspector:GetVBar():SetScroll(state.inspectorScroll or 0)
        end)
    end

    function f:RefreshExampleDrafts()
        if TS.Editor.Frame == self and IsValid(listPanel) then
            listPanel:SetDrafts(TS.Editor.ExampleDrafts)
            listPanel:SetActive(doc and doc.id, dirty)
        end
    end

    f.OnRemove = function()
        problemRefreshVersion = problemRefreshVersion + 1
        if TS.Editor.ReceiveList == receiveList then
            TS.Editor.ReceiveList = nil
        end
        if TS.Editor.ReceiveDocument == receiveDoc then
            TS.Editor.ReceiveDocument = nil
        end
        if TS.Editor.SaveResult == saveResult then
            TS.Editor.SaveResult = nil
        end

        if TS.Editor.Frame ~= f then
            return
        end

        if IsValid(TS.Editor.Modal) then
            TS.Editor.Modal:Remove()
        end
        if IsValid(TS.Editor.AddonSettingsFrame) then
            TS.Editor.AddonSettingsFrame:Remove()
        end
        if IsValid(TS.Editor.ExamplesFrame) then
            TS.Editor.ExamplesFrame:Remove()
        end
        if IsValid(TS.Editor.PopupMenu) and TS.Editor.PopupMenu.Close then
            TS.Editor.PopupMenu:Close()
        end
        TS.Editor.Frame = nil
    end

    f.Think = function()
        if TS.Editor.HelpOpen
            or TS.Editor.ExamplesOpen
            or TS.Editor.DialogueSettingsOpen
            or TS.Editor.AddonSettingsOpen
            or IsValid(TS.Editor.Modal)
            or IsValid(TS.Editor.PopupMenu)
            or (TS.Editor.PickerDepth and TS.Editor.PickerDepth > 0)
        then
            return
        end
        if gui.IsGameUIVisible() and not gui.IsConsoleVisible() and not (TS.Runtime.IsActive and TS.Runtime.IsActive()) then
            gui.HideGameUI()
            confirmIfDirty(reallyClose)
        end
    end

    local rebuilding = istable(TS.Editor.RestoreState)

    if rebuilding then
        f:RestoreState(TS.Editor.RestoreState)
        TS.Editor.RestoreState = nil
    end

    if istable(TS.Editor.DocumentList) then
        receiveList(TS.Editor.DocumentList)
    end

    if not rebuilding or not istable(TS.Editor.DocumentList) then
        TS.Editor.RequestDocuments()
    end

    if not TS.Editor.GetSetting("help_seen") then
        TS.Editor.SetSetting("help_seen", true)
        timer.Simple(0.2, function()
            if IsValid(f) then
                TS.Editor.OpenHelp()
            end
        end)
    end
end

local function activeEditorPopup()
    local managed = TS.Editor.GetActiveModalPanel and TS.Editor.GetActiveModalPanel()
    if IsValid(managed) then
        return managed
    end
    if IsValid(TS.Editor.Modal) then
        return TS.Editor.Modal
    end
    if IsValid(TS.Editor.ReferencePicker) then
        return TS.Editor.ReferencePicker
    end
    if IsValid(TS.Editor.PopupMenu) then
        local overlay = TS.Editor.PopupMenu:GetParent()
        if IsValid(overlay) then
            return overlay
        end
    end
    for _, key in ipairs({
        "HelpFrame",
        "ExamplesFrame",
        "DialogueSettingsFrame",
        "AddonSettingsFrame",
        "Frame",
    }) do
        local panel = TS.Editor[key]
        if IsValid(panel) and panel:IsVisible() then
            return panel
        end
    end
end

local editorHadSystemFocus = system.HasFocus() ~= false
local restoreEditorFocus = false

hook.Add("Think", "Talksmith.RestoreEditorFocus", function()
    local hasSystemFocus = system.HasFocus()
    if hasSystemFocus == false then
        if editorHadSystemFocus then
            restoreEditorFocus = IsValid(activeEditorPopup())
        end
        editorHadSystemFocus = false
        return
    end
    if not editorHadSystemFocus then
        editorHadSystemFocus = true
        restoreEditorFocus = true
    end
    if not restoreEditorFocus or gui.IsConsoleVisible() or gui.IsGameUIVisible() then
        return
    end
    restoreEditorFocus = false
    local panel = activeEditorPopup()
    if not IsValid(panel) then
        return
    end
    if panel._talksmithManagedModal and TS.Editor.ActivateModalPanel then
        TS.Editor.ActivateModalPanel(panel, panel._talksmithDermaModal)
    else
        panel:MakePopup()
        panel:MoveToFront()
    end
end)

hook.Add(
    "Talksmith.EditorCatalogChanged",
    "Talksmith.RefreshCatalogInspector",
    function()
        local frame = TS.Editor.Frame
        if IsValid(frame) and frame.RefreshCatalogInspector then
            frame:RefreshCatalogInspector()
        end
    end
)
