local TS = Talksmith

function TS.API.GetVersion()
    return TS.API.Version
end

function TS.Dialogues.Get(id)
    local safeID = TS.Utils.SafeID(id or "")

    return TS.Dialogues.Registry[safeID]
end

function TS.Dialogues.Exists(id)
    return TS.Dialogues.Get(id) ~= nil
end

function TS.Dialogues.Validate(doc)
    return TS.Validation.ValidateDialogue(doc)
end

function TS.Dialogues.Export(id, pretty)
    local doc = TS.Dialogues.Get(id)
    if not doc then
        return nil, "not_found"
    end
    return util.TableToJSON(doc, pretty ~= false)
end

function TS.Dialogues.Register(id, data, author, expected)
    id = TS.Utils.SafeID(id or "")
    if not id or not istable(data) then
        return false, "bad_id"
    end

    local doc = TS.Utils.Copy(data)
    doc.id = id
    local ok, issues = TS.Validation.ValidateDialogue(doc)
    if not ok then
        return false, "invalid", issues
    end

    if SERVER and TS.Dialogues.Save then
        local current = TS.Dialogues.Get(id)
        local revision = expected
        if revision == nil then
            revision = current and current.meta and current.meta.revision or 0
        end
        return TS.Dialogues.Save(doc, author or "Talksmith API", revision)
    end
    TS.Dialogues.Registry[id] = doc
    return true, doc
end

function TS.Dialogues.Import(raw, author, expected)
    local doc = isstring(raw) and util.JSONToTable(raw, false, true) or raw
    if not istable(doc) then
        return false, "invalid"
    end
    return TS.Dialogues.Register(doc.id, doc, author, expected)
end

function TS.Utils.MapMatches(filter, currentMap)
    currentMap = currentMap or game.GetMap()
    if filter == nil or filter == "*" then
        return true
    end
    if isstring(filter) then
        return filter == currentMap
    end
    if istable(filter) then
        return TS.Utils.InList(filter, "*") or TS.Utils.InList(filter, currentMap)
    end
    return false
end
