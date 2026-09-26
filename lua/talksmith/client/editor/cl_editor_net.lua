local TS = Talksmith
local MAX_NET_PAYLOAD = 60000
local MAX_EDITOR_CATALOG_BYTES = 2097152

function TS.Editor.RequestOpen()
    net.Start("ts_editor_open_request")
    net.SendToServer()
end

concommand.Add("talksmith_menu", TS.Editor.RequestOpen)

hook.Add("PopulateToolMenu", "Talksmith.EditorToolMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Talksmith", "TalksmithStudio", "Studio", "", "", function(panel)
        local button = panel:Button(TS.L("open") .. " " .. TS.L("editor"))
        if IsValid(button) then
            button.DoClick = TS.Editor.RequestOpen
        end
    end)
end)

local function receiveCatalog(raw)
    local cat = TS.Editor.Transfer.Decode(raw, MAX_EDITOR_CATALOG_BYTES)
    if not cat then return end
    TS.Editor.Catalog = {
        api_version = cat.api_version,
        actions = cat.actions or {},
        conditions = cat.conditions or {},
        integrations = cat.integrations or {},
        providers = cat.providers or {},
        variables = cat.variables or {},
    }
    TS.Editor.Open()
end
TS.Editor.Transfer.Handlers.catalog = receiveCatalog

net.Receive("ts_editor_open", function()
    local n = net.ReadUInt(18)
    if n <= 0 or n > MAX_NET_PAYLOAD then
        return
    end
    local raw = util.Decompress(net.ReadData(n) or "", MAX_EDITOR_CATALOG_BYTES)
    if not raw then
        return
    end
    receiveCatalog(raw)
end)

local function receiveDocs(raw, isDoc)
    local data = TS.Editor.Transfer.Decode(raw,
        isDoc and TS.Config.max_document_bytes or TS.Editor.Transfer.ListLimit)
    if not data then return end
    if isDoc then
        if TS.Editor.ReceiveDocument then
            TS.Editor.ReceiveDocument(data)
        end
    else
        if TS.Editor.ReceiveList then
            TS.Editor.ReceiveList(data)
        end
    end
end
TS.Editor.Transfer.Handlers.list = function(raw) receiveDocs(raw, false) end
TS.Editor.Transfer.Handlers.document = function(raw) receiveDocs(raw, true) end

net.Receive("ts_editor_docs", function()
    local isDoc = net.ReadBool()
    local n = net.ReadUInt(20)
    if n <= 0 or n > MAX_NET_PAYLOAD then
        return
    end
    local raw = util.Decompress(net.ReadData(n) or "", isDoc and TS.Config.max_document_bytes or TS.Editor.Transfer.ListLimit)
    if not raw then
        return
    end
    receiveDocs(raw, isDoc)
end)

net.Receive("ts_editor_result", function()
    local ok = net.ReadBool()
    local result = net.ReadString()
    local issues = util.JSONToTable(net.ReadString() or "[]") or {}
    if TS.Editor.SaveResult then
        TS.Editor.SaveResult(ok, result, issues)
    end
end)

function TS.Editor.Save(doc)
    local json = util.TableToJSON(doc)
    if not json or #json > TS.Config.max_document_bytes then
        TS.Runtime.Notify(TS.L("save_failed", "too_large"), NOTIFY_ERROR, 4)
        return
    end
    local raw = util.Compress(json)
    if not raw then
        TS.Runtime.Notify(TS.L("save_failed", "too_large"), NOTIFY_ERROR, 4)
        return
    end
    if #raw > MAX_NET_PAYLOAD then
        return TS.Editor.Transfer.Send("save", raw, nil, doc.meta and doc.meta.revision or 0)
    end
    TS.Editor.Transfer.Cancel("save")
    net.Start("ts_editor_save")
    net.WriteUInt(#raw, 20)
    net.WriteData(raw, #raw)
    net.WriteUInt(doc.meta and doc.meta.revision or 0, 32)
    net.SendToServer()
end

local MANAGE = { delete = 0, duplicate = 1, rename = 2 }
function TS.Editor.Manage(op, id, newid)
    net.Start("ts_editor_manage")
    net.WriteUInt(MANAGE[op] or 0, 2)
    net.WriteString(id or "")
    if op == "rename" then
        net.WriteString(newid or "")
    end
    net.SendToServer()
end

local ActorOPS = { place = 0, save = 1, remove = 2, load = 3, update = 4, copy_aim = 5, vj_bind = 6, vj_unbind = 7 }
function TS.Editor.ManageActor(op, id, mode)
    local code = ActorOPS[op]
    if code == nil then
        return
    end
    net.Start("ts_editor_actor")
    net.WriteUInt(code, 3)
    if op == "place" or op == "update" or op == "copy_aim" or op == "vj_bind" then
        net.WriteString(id or "")
    end
    if op == "vj_bind" then net.WriteBool(mode == "native") end
    net.SendToServer()
end

net.Receive("ts_editor_actor_result", function()
    local ok = net.ReadBool()
    local code = net.ReadString()
    local key = code == "copy_done" and "copy_transform_done"
        or code == "vj_bound" and "vj_bound"
        or code == "vj_unbound" and "vj_unbound"
        or code == "vj_error" and "vj_error"
        or code == "updated" and "status_saved"
        or "copy_aim_invalid"
    TS.Runtime.Notify(TS.L(key), ok and NOTIFY_GENERIC or NOTIFY_ERROR, 3)
end)
