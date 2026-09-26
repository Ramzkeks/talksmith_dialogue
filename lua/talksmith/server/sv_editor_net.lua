local TS = Talksmith
local MAX_EDITOR_CATALOG_BYTES = 2097152
local MAX_NET_PAYLOAD = 60000
local EDITOR_CHAT_COMMAND = "!talksmith_menu"
for _, s in ipairs({
    "ts_editor_open",
    "ts_editor_open_request",
    "ts_editor_docs",
    "ts_editor_save",
    "ts_editor_result",
    "ts_editor_actor",
    "ts_editor_actor_result",
    "ts_editor_manage",
    "ts_editor_export",
}) do
    util.AddNetworkString(s)
end

net.Receive("ts_editor_export", function(len, p)
    if len > 600 or not TS.Network.Allow(p, "export", 0.5) or not TS.Permissions.CanUseEditor(p) then
        return
    end
    local id = TS.Utils.SafeID(net.ReadString() or "")
    local doc = id and TS.Dialogues.Get(id)
    if not doc then
        return
    end
    local json = util.TableToJSON(doc, true)
    if not json or #json > TS.Config.max_document_bytes then
        return
    end
    local payload = util.Compress(json)
    if not payload then return end
    if #payload > MAX_NET_PAYLOAD then
        return TS.Editor.Transfer.Send("export", payload, p)
    end
    TS.Editor.Transfer.Cancel("export", p)
    net.Start("ts_editor_export")
    net.WriteString(id)
    net.WriteUInt(#payload, 20)
    net.WriteData(payload, #payload)
    net.Send(p)
end)

local function catalog()
    local function isAvailable(definition)
        if definition.integration then
            return TS.Integrations.IsAvailable(definition.integration)
        end
        if definition.provider_kind then
            return TS.Providers.HasAvailable(definition.provider_kind, definition.provider_method)
        end
        return true
    end

    local function strip(src, kind)
        local out = {}
        for id, d in pairs(src) do
            out[id] = {
                id = id,
                name = d.name,
                description = d.description,
                params = d.params,
                category = d.category,
                integration = d.integration,
                provider_kind = d.provider_kind,
                provider_method = d.provider_method,
                safe = d.safe == true,
                dangerous = d.dangerous == true,
                vj_scene_action = d.vj_scene_action == true,
                permission = d.permission,
                available = isAvailable(d),
            }
        end
        return out
    end
    local variables = {}
    for id, d in pairs(TS.Integrations.Variables or {}) do
        variables[id] = {
            id = id,
            name = d.name,
            description = d.description,
            integration = d.integration,
            provider_kind = d.provider_kind,
            provider_method = d.provider_method,
            available = isAvailable(d),
        }
    end
    local providers = {}
    for kind, group in pairs(TS.Providers.Registry or {}) do
        providers[kind] = {}
        for id, d in pairs(group) do
            local methods = {}
            for key, value in pairs(d) do
                if isfunction(value) then
                    methods[key] = true
                end
            end
            providers[kind][id] = {
                id = id,
                kind = kind,
                name = d.name,
                integration = d.integration,
                available = isAvailable(d),
                methods = methods,
            }
        end
    end
    return {
        api_version = TS.API.IntegrationVersion,
        actions = strip(TS.Actions.Registry, "action"),
        conditions = strip(TS.Conditions.Registry, "condition"),
        integrations = TS.Integrations.GetCatalog and TS.Integrations.GetCatalog() or {},
        providers = providers,
        variables = variables,
    }
end

local function openEditor(p)
    if
        not IsValid(p)
        or not p:IsPlayer()
        or not TS.Network.Allow(p, "editor_open", 1)
        or not TS.Permissions.CanUseEditor(p)
    then
        return
    end
    local json = util.TableToJSON(catalog()) or "{}"
    if #json > MAX_EDITOR_CATALOG_BYTES then
        TS.Logging.Log(0, "Editor catalog exceeds the safe payload limit")
        return
    end
    local raw = util.Compress(json)
    if not raw then return end
    if #raw > MAX_NET_PAYLOAD then
        return TS.Editor.Transfer.Send("catalog", raw, p)
    end
    TS.Editor.Transfer.Cancel("catalog", p)
    net.Start("ts_editor_open")
    net.WriteUInt(#raw, 18)
    net.WriteData(raw, #raw)
    net.Send(p)
end

net.Receive("ts_editor_open_request", function(len, p)
    if len > 0 then return end
    openEditor(p)
end)

hook.Add("PlayerSay", "Talksmith.EditorChatCommand", function(p, text)
    if not isstring(text) or string.lower(string.Trim(text)) ~= EDITOR_CHAT_COMMAND then
        return
    end

    openEditor(p)
    return ""
end)

local function sendDocList(p)
    local payload = {}
    for k, d in pairs(TS.Dialogues.Registry) do
        payload[#payload + 1] = {
            id = k,
            title = d.meta.title,
            author = d.meta.author,
            modified = d.meta.modified,
            revision = d.meta.revision,
        }
    end
    local json = util.TableToJSON(payload) or "[]"
    if #json > TS.Editor.Transfer.ListLimit then
        TS.Logging.Log(0, "Editor dialogue list exceeds the safe payload limit")
        return false
    end
    local raw = util.Compress(json)
    if not raw then return false end
    if #raw > MAX_NET_PAYLOAD then
        return TS.Editor.Transfer.Send("list", raw, p)
    end
    TS.Editor.Transfer.Cancel("list", p)
    net.Start("ts_editor_docs")
    net.WriteBool(false)
    net.WriteUInt(#raw, 20)
    net.WriteData(raw, #raw)
    net.Send(p)
    return true
end

net.Receive("ts_editor_docs", function(len, p)
    if len > 600 or not TS.Network.Allow(p, "docs", 0.5) or not TS.Permissions.CanUseEditor(p) then
        return
    end
    local id = TS.Utils.SafeID(net.ReadString() or "")
    if not id then
        return sendDocList(p)
    end
    local doc = TS.Dialogues.Get(id)
    if not doc then
        return sendDocList(p)
    end
    local json = util.TableToJSON(doc) or "{}"
    if #json > TS.Config.max_document_bytes then
        return
    end
    local raw = util.Compress(json)
    if not raw then return end
    if #raw > MAX_NET_PAYLOAD then
        return TS.Editor.Transfer.Send("document", raw, p)
    end
    TS.Editor.Transfer.Cancel("document", p)
    net.Start("ts_editor_docs")
    net.WriteBool(true)
    net.WriteUInt(#raw, 20)
    net.WriteData(raw, #raw)
    net.Send(p)
end)

local function resultIssues(issues)
    local raw = util.TableToJSON(issues or {}) or "[]"
    if #raw > 60000 then
        return "[{\"severity\":\"error\",\"path\":\"/\",\"message\":\"Too many validation issues\"}]"
    end
    return raw
end

local function sendEditorResult(player, ok, code, issues)
    net.Start("ts_editor_result")
    net.WriteBool(ok == true)
    net.WriteString(tostring(code or ""))
    net.WriteString(resultIssues(issues))
    net.Send(player)
end

local function saveDocument(raw, p, expected)
    if not TS.Permissions.CanUseEditor(p) then return end
    local doc = TS.Editor.Transfer.Decode(raw, TS.Config.max_document_bytes)
    if not doc then
        sendEditorResult(p, false, "invalid")
        return
    end
    local id = istable(doc) and TS.Utils.SafeID(doc.id or "")
    local right = id and TS.Dialogues.Exists(id) and "talksmith.dialogues.edit" or "talksmith.dialogues.create"
    if not id or not TS.Permissions.Has(p, right) then
        sendEditorResult(p, false, "permission_denied")
        return
    end

    local checked, valid, validationIssues = TS.Utils.SafeCall(
        "validate network editor document",
        TS.Validation.ValidateDialogue,
        doc
    )
    if not checked or not valid then
        sendEditorResult(p, false, "invalid", validationIssues)
        return
    end

    local canPublish, deniedRights = TS.Permissions.CanPublishDialogue(p, doc)
    if not canPublish then
        local issues = {}
        for _, deniedRight in ipairs(deniedRights or {}) do
            issues[#issues + 1] = {
                severity = "error",
                path = "actions",
                message = "Missing permission: " .. deniedRight,
            }
        end
        sendEditorResult(p, false, "permission_denied", issues)
        return
    end

    local ok, a, b = TS.Dialogues.Save(doc, p:SteamID64(), expected)
    sendEditorResult(p, ok, a, b)
    if ok then
        sendDocList(p)
    end
end

TS.Editor.Transfer.Handlers.save = saveDocument

net.Receive("ts_editor_save", function(len, p)
    if not TS.Network.Allow(p, "save", 1)
        or not TS.Permissions.CanUseEditor(p)
        or len / 8 > MAX_NET_PAYLOAD + 16
    then
        return
    end
    local n = net.ReadUInt(20)
    if n > MAX_NET_PAYLOAD or n * 8 + 52 > len then
        return
    end
    local raw = util.Decompress(net.ReadData(n) or "", TS.Config.max_document_bytes)
    if not raw or #raw > TS.Config.max_document_bytes then
        return
    end
    saveDocument(raw, p, net.ReadUInt(32))
end)

net.Receive("ts_editor_manage", function(len, p)
    if len > 1200 or not TS.Network.Allow(p, "manage", 0.5) or not TS.Permissions.CanUseEditor(p) then
        return
    end
    local op = net.ReadUInt(2)
    local id = TS.Utils.SafeID(net.ReadString() or "")
    if not id then
        return
    end
    if op == 0 then
        if TS.Permissions.Has(p, "talksmith.dialogues.delete") then
            local ok, reason = TS.Dialogues.Delete(id)
            if not ok then
                TS.Logging.Log(0, "Dialogue delete failed for " .. id .. ": " .. tostring(reason))
            end
        end
    elseif op == 1 then
        if not TS.Permissions.Has(p, "talksmith.dialogues.create")
            or not TS.Permissions.Has(p, "talksmith.dialogues.publish")
        then
            return
        end
        local source = TS.Dialogues.Get(id)
        if not source or not TS.Permissions.CanPublishDialogue(p, source) then
            return
        end
        local newid = id .. "_copy"
        local i = 2
        while TS.Dialogues.Registry[newid] do
            newid = id .. "_copy" .. i
            i = i + 1
            if i > 99 then
                return
            end
        end
        local ok, reason = TS.Dialogues.Duplicate(id, newid, p:SteamID64())
        if not ok then
            TS.Logging.Log(0, "Dialogue duplicate failed for " .. id .. ": " .. tostring(reason))
        end
    elseif op == 2 then
        if not TS.Permissions.Has(p, "talksmith.dialogues.edit")
            or not TS.Permissions.Has(p, "talksmith.dialogues.create")
            or not TS.Permissions.Has(p, "talksmith.dialogues.delete")
            or not TS.Permissions.Has(p, "talksmith.dialogues.publish")
        then
            return
        end
        local source = TS.Dialogues.Get(id)
        if not source or not TS.Permissions.CanPublishDialogue(p, source) then
            return
        end
        local newid = TS.Utils.SafeID(net.ReadString() or "")
        if not newid then
            return
        end
        local ok, reason = TS.Dialogues.Rename(id, newid, p:SteamID64())
        if not ok then
            TS.Logging.Log(0, "Dialogue rename failed for " .. id .. ": " .. tostring(reason))
        end
    end
    sendDocList(p)
end)

local function aimedActor(p)
    local e = p:GetEyeTrace().Entity
    if TS.Actors.IsActor(e) and p:GetPos():DistToSqr(e:GetPos()) < 65536 then
        return e
    end
end

local function sendActorResult(p, ok, code)
    net.Start("ts_editor_actor_result")
    net.WriteBool(ok)
    net.WriteString(code or "")
    net.Send(p)
end

local function aimedModelEntity(p)
    local e = p:GetEyeTrace().Entity
    if not IsValid(e) or e == p or e:IsWorld() or p:GetPos():DistToSqr(e:GetPos()) > 262144 then
        return
    end
    local model = e:GetModel()
    if not TS.Utils.IsModelAllowed(model) then
        return
    end
    return e, model
end

net.Receive("ts_editor_actor", function(len, p)
    if len > 600
        or not TS.Network.Allow(p, "actor_manage", 0.5)
        or not TS.Permissions.CanUseEditor(p, "talksmith.actors.manage")
    then
        return
    end
    local op = net.ReadUInt(3)
    if op == 0 then
        local id = TS.Utils.SafeID(net.ReadString() or "")
        local d = TS.Dialogues.Get(id)
        if d then
            local tr = p:GetEyeTrace()
            TS.Actors.Create(p, {
                model = d.settings.actor_model,
                name = d.settings.actor_name,
                subtitle = d.settings.actor_subtitle,
                dialogue = id,
                pos = tr.HitPos + tr.HitNormal * 4,
                ang = Angle(0, p:EyeAngles().y + 180, 0),
            })
            if TS.Config.autosave_actors then
                TS.Actors.SaveLayout()
            end
        end
    elseif op == 1 then
        TS.Actors.SaveLayout()
    elseif op == 2 then
        local e = aimedActor(p)
        if e then
            e:Remove()
            if TS.Config.autosave_actors then
                TS.Actors.SaveLayout()
            end
        end
    elseif op == 3 then
        TS.Actors.LoadLayout()
    elseif op == 4 then
        local id = TS.Utils.SafeID(net.ReadString() or "")
        local d = TS.Dialogues.Get(id)
        local e = aimedActor(p)
        if d and e then
            TS.Actors.RemoveByDialogue(id, e)
            e.ModelOverride = false
            TS.Actors.SetDialogue(e, id)
            if TS.Config.autosave_actors then
                TS.Actors.SaveLayout()
            end
            sendActorResult(p, true, "updated")
        end
    elseif op == 6 or op == 7 then
        local id = op == 6 and TS.Utils.SafeID(net.ReadString() or "") or nil
        local mode = op == 6 and net.ReadBool() and "native" or "staged"
        local entity = p:GetEyeTrace().Entity
        if not TS.VJ or not IsValid(entity) or p:GetPos():DistToSqr(entity:GetPos()) >= 65536 then
            return sendActorResult(p, false, "vj_error")
        end
        local binding = TS.VJ.Bindings[entity]
        if binding and (binding.attempt or binding.player or binding.owner) then
            return sendActorResult(p, false, "vj_error")
        end
        local ok
        if op == 6 then
            ok = TS.VJ.Bind(entity, id, { mode = mode })
        else
            ok = TS.VJ.Unbind(entity)
        end
        sendActorResult(p, ok == true, ok and (op == 6 and (mode == "native" and "updated" or "vj_bound") or "vj_unbound") or "vj_error")
    elseif op == 5 then
        local id = TS.Utils.SafeID(net.ReadString() or "")
        local d = TS.Dialogues.Get(id)
        local source, model = aimedModelEntity(p)
        if not d or not source then
            return sendActorResult(p, false, "invalid_target")
        end
        local actor = TS.Actors.Create(p, {
            model = model,
            model_override = true,
            name = d.settings.actor_name,
            subtitle = d.settings.actor_subtitle,
            dialogue = id,
            pos = source:GetPos(),
            ang = Angle(0, source:GetAngles().y, 0),
        })
        if not IsValid(actor) then
            return sendActorResult(p, false, "invalid_target")
        end
        if TS.Config.autosave_actors then
            TS.Actors.SaveLayout()
        end
        sendActorResult(p, true, "copy_done")
    end
end)
