local TS = Talksmith
local MAX_NET_PAYLOAD = 60000
local MAX_EDITOR_CATALOG_BYTES = 2097152

net.Receive("ts_editor_open", function()
    local n = net.ReadUInt(18)
    if n <= 0 or n > MAX_NET_PAYLOAD then
        return
    end
    local raw = util.Decompress(net.ReadData(n) or "", MAX_EDITOR_CATALOG_BYTES)
    if not raw then
        return
    end
    local cat = util.JSONToTable(raw or "") or {}
    TS.Editor.Catalog = {
        api_version = cat.api_version,
        actions = cat.actions or {},
        conditions = cat.conditions or {},
        integrations = cat.integrations or {},
        providers = cat.providers or {},
        variables = cat.variables or {},
    }
    TS.Editor.Open()
end)

net.Receive("ts_editor_docs", function()
    local isDoc = net.ReadBool()
    local n = net.ReadUInt(20)
    if n <= 0 or n > MAX_NET_PAYLOAD then
        return
    end
    local raw = util.Decompress(net.ReadData(n) or "", TS.Config.max_document_bytes)
    if not raw then
        return
    end
    local data = util.JSONToTable(raw or "", false, true)
    if not data then
        return
    end
    if isDoc then
        if TS.Editor.ReceiveDocument then
            TS.Editor.ReceiveDocument(data)
        end
    else
        if TS.Editor.ReceiveList then
            TS.Editor.ReceiveList(data)
        end
    end
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
    local raw = util.Compress(util.TableToJSON(doc) or "")
    if not raw or #raw > MAX_NET_PAYLOAD then
        TS.Runtime.Notify(TS.L("save_failed", "too_large"), NOTIFY_ERROR, 4)
        return
    end
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

local ActorOPS = { place = 0, save = 1, remove = 2, load = 3, update = 4, copy_aim = 5 }
function TS.Editor.ManageActor(op, id)
    local code = ActorOPS[op]
    if code == nil then
        return
    end
    net.Start("ts_editor_actor")
    net.WriteUInt(code, 3)
    if op == "place" or op == "update" or op == "copy_aim" then
        net.WriteString(id or "")
    end
    net.SendToServer()
end

net.Receive("ts_editor_actor_result", function()
    local ok = net.ReadBool()
    local code = net.ReadString()
    local key = code == "copy_done" and "copy_transform_done"
        or code == "updated" and "status_saved"
        or "copy_aim_invalid"
    TS.Runtime.Notify(TS.L(key), ok and NOTIFY_GENERIC or NOTIFY_ERROR, 3)
end)
