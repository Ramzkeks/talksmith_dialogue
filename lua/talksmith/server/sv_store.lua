local TS = Talksmith
TS.Dialogues.Registry = TS.Dialogues.Registry or {}
local root = "talksmith/dialogues"
file.CreateDir("talksmith")
file.CreateDir(root)
file.CreateDir("talksmith/backups")

local function appendCanonical(value, out, seen, depth)
    if depth > 64 then return false end
    local kind = type(value)
    if kind == "nil" then
        out[#out + 1] = "z"
        return true
    end
    if kind == "boolean" then
        out[#out + 1] = value and "b1" or "b0"
        return true
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return false end
        out[#out + 1] = "n" .. string.format("%.17g", value)
        return true
    end
    if kind == "string" then
        out[#out + 1] = "s" .. tostring(#value) .. ":" .. value
        return true
    end
    if kind ~= "table" or seen[value] then return false end

    seen[value] = true
    local keys = {}
    for key in pairs(value) do
        local keyType = type(key)
        if keyType ~= "number" and keyType ~= "string" then
            seen[value] = nil
            return false
        end
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        local aType, bType = type(a), type(b)
        if aType ~= bType then return aType < bType end
        return a < b
    end)
    out[#out + 1] = "{"
    for _, key in ipairs(keys) do
        if not appendCanonical(key, out, seen, depth + 1)
            or not appendCanonical(value[key], out, seen, depth + 1)
        then
            seen[value] = nil
            return false
        end
    end
    out[#out + 1] = "}"
    seen[value] = nil
    return true
end

function TS.Dialogues.DependencyFingerprint(document)
    if not istable(document) then return nil end
    local payload = TS.Utils.Copy(document)
    if istable(payload.meta) then
        payload.meta.open_dialogue_revisions = nil
        payload.meta.open_dialogue_fingerprints = nil
    end
    local out = {}
    if not appendCanonical(payload, out, {}, 0) then return nil end
    return util.SHA256(table.concat(out))
end

local function snapshotActionDependencies(document, entries, revisions, fingerprints)
    local actionLimit = math.Clamp(math.floor(tonumber(TS.Config.max_action_entries) or 16), 1, 64)
    for index = 1, math.min(istable(entries) and #entries or 0, actionLimit) do
        local entry = entries[index]
        if istable(entry)
            and entry.id == "core.open_dialogue"
            and istable(entry.params)
            and isstring(entry.params.dialogue)
        then
            local targetID = TS.Utils.SafeID(entry.params.dialogue)
            if not targetID or targetID ~= entry.params.dialogue then
                return false, "invalid_dependency"
            end
            local target = targetID == document.id and document or TS.Dialogues.Get(targetID)
            local revision = target and target.meta and tonumber(target.meta.revision)
            if not revision
                or revision < 0
                or revision ~= math.floor(revision)
                or revision > 4294967295
            then
                return false, "missing_dependency"
            end
            local fingerprint = TS.Dialogues.DependencyFingerprint(target)
            if not isstring(fingerprint) or #fingerprint ~= 64 then
                return false, "invalid_dependency"
            end
            revisions[targetID] = revision
            fingerprints[targetID] = fingerprint
        end
    end
    return true
end

function TS.Dialogues.BuildDependencySnapshot(document)
    if not istable(document) or not istable(document.nodes) then
        return nil, nil, "invalid_dependency"
    end

    local revisions = {}
    local fingerprints = {}
    local nodeLimit = math.Clamp(math.floor(tonumber(TS.Config.max_nodes) or 256), 1, 4096)
    local optionLimit = math.Clamp(math.floor(tonumber(TS.Config.max_options) or 6), 1, 7)
    local nodeCount = 0
    for _, node in pairs(document.nodes) do
        nodeCount = nodeCount + 1
        if nodeCount > nodeLimit or not istable(node) then
            return nil, nil, "invalid_dependency"
        end
        local ok, reason = snapshotActionDependencies(document, node.actions, revisions, fingerprints)
        if not ok then return nil, nil, reason end
        for index = 1, math.min(istable(node.options) and #node.options or 0, optionLimit) do
            local option = node.options[index]
            if istable(option) then
                ok, reason = snapshotActionDependencies(document, option.actions, revisions, fingerprints)
                if not ok then return nil, nil, reason end
            end
        end
    end
    return revisions, fingerprints
end

function TS.Dialogues.IsDependencyCurrent(document, targetID)
    targetID = TS.Utils.SafeID(targetID or "")
    if not targetID or not istable(document) or not istable(document.meta) then
        return false
    end
    local snapshot = document.meta.open_dialogue_revisions
    local fingerprintSnapshot = document.meta.open_dialogue_fingerprints
    local expected = istable(snapshot) and tonumber(snapshot[targetID]) or nil
    local expectedFingerprint = istable(fingerprintSnapshot) and fingerprintSnapshot[targetID] or nil
    local target = TS.Dialogues.Get(targetID)
    local current = target and target.meta and tonumber(target.meta.revision) or nil
    local currentFingerprint = target and TS.Dialogues.DependencyFingerprint(target) or nil
    return expected ~= nil
        and current ~= nil
        and expected == current
        and isstring(expectedFingerprint)
        and expectedFingerprint == currentFingerprint
end

local function backup(doc)
    local dir = "talksmith/backups/" .. doc.id
    file.CreateDir(dir)
    local backupLimit = math.Clamp(math.floor(tonumber(TS.Config.backups) or 5), 0, 50)
    if backupLimit == 0 then
        return true
    end

    local json = util.TableToJSON(doc, true)
    local target = dir .. "/" .. os.time() .. "_r" .. (doc.meta.revision or 0) .. ".json"
    if not json or not TS.Utils.WriteDataFile(target, json) then
        return false
    end

    local files = file.Find(dir .. "/*.json", "DATA")
    table.sort(files)
    while #files > backupLimit do
        local old = dir .. "/" .. table.remove(files, 1)
        if file.Delete(old) ~= true then
            TS.Logging.Log(0, "Could not prune old dialogue backup " .. old)
        end
    end
    return true
end

function TS.Dialogues.Reload()
    TS.Dialogues.Registry = {}
    local files = file.Find(root .. "/*.json", "DATA")
    TS.Storage.DialogueFileCount = #files
    for _, name in ipairs(files) do
        local raw = file.Read(root .. "/" .. name, "DATA") or ""
        if #raw > TS.Config.max_document_bytes then
            TS.Logging.Log(0, "Rejected " .. name .. ": file exceeds max_document_bytes")
        else
            local decoded, doc = pcall(util.JSONToTable, raw, true, true)
            local checked, ok, issues = false, false, nil
            if decoded then
                checked, ok, issues = TS.Utils.SafeCall("validate " .. name, TS.Validation.ValidateDialogue, doc)
            end
            if decoded and checked and ok and name == doc.id .. ".json" then
                TS.Dialogues.Registry[doc.id] = doc
            else
                local reason = decoded and checked and ok and "filename does not match document id"
                    or (util.TableToJSON(issues or {}) or "validation_error")
                TS.Logging.Log(0, "Rejected " .. name .. ": " .. reason)
            end
        end
    end
    return TS.Dialogues.Registry
end

function TS.Dialogues.Save(doc, author, expected)
    local id = TS.Utils.SafeID(doc and doc.id or "")
    if not id then
        return false, "bad_id"
    end
    local old = TS.Dialogues.Registry[id]
    if old and tonumber(expected) ~= tonumber(old.meta.revision) then
        return false, "revision_conflict"
    end
    local target = root .. "/" .. id .. ".json"
    if not old and file.Exists(target, "DATA") then
        return false, "file_exists"
    end
    if author ~= nil and (not isstring(author) or TS.Utils._UTF8Length(author) > 64) then
        return false, "invalid_author"
    end
    if not istable(doc.meta) then
        local _, issues = TS.Validation.ValidateDialogue(doc)
        return false, "invalid", issues
    end

    local candidate = TS.Utils.Copy(doc)
    local now = os.time()
    candidate.meta.author = author
    candidate.meta.modified = now
    candidate.meta.created = candidate.meta.created or now
    candidate.meta.revision = (old and old.meta.revision or 0) + 1
    candidate.meta.open_dialogue_revisions = nil
    candidate.meta.open_dialogue_fingerprints = nil
    local dependencies, fingerprints, dependencyError = TS.Dialogues.BuildDependencySnapshot(candidate)
    if not dependencies or not fingerprints then
        return false, dependencyError
    end
    candidate.meta.open_dialogue_revisions = dependencies
    candidate.meta.open_dialogue_fingerprints = fingerprints

    local checked, ok, issues = TS.Utils.SafeCall("validate editor document", TS.Validation.ValidateDialogue, candidate)
    if not checked or not ok then
        return false, "invalid", issues
    end
    local raw = util.TableToJSON(candidate, true)
    if not raw or #raw > TS.Config.max_document_bytes then
        return false, "too_large"
    end
    if old and not backup(old) then
        return false, "backup_failed"
    end
    if not TS.Utils.WriteDataFile(target, raw) then
        return false, "write_failed"
    end
    doc.meta = TS.Utils.Copy(candidate.meta)
    TS.Dialogues.Registry[id] = candidate
    hook.Run("Talksmith.DialogueSaved", id, candidate.meta.revision, author)
    return true, candidate.meta.revision
end

function TS.Dialogues.Delete(id)
    id = TS.Utils.SafeID(id or "")
    local doc = id and TS.Dialogues.Registry[id]
    if not doc then
        return false, "not_found"
    end
    if not backup(doc) then
        return false, "backup_failed"
    end
    local target = root .. "/" .. id .. ".json"
    if file.Exists(target, "DATA") and file.Delete(target) ~= true then
        return false, "delete_failed"
    end
    TS.Dialogues.Registry[id] = nil
    hook.Run("Talksmith.DialogueDeleted", id)
    return true
end

function TS.Dialogues.Duplicate(id, newid, author)
    id = TS.Utils.SafeID(id or "")
    newid = TS.Utils.SafeID(newid or "")
    local src = id and TS.Dialogues.Registry[id]
    if not src then
        return false, "not_found"
    end
    if not newid or TS.Dialogues.Registry[newid] then
        return false, "bad_id"
    end
    local copy = TS.Utils.Copy(src)
    copy.id = newid
    copy.meta.revision = 0
    copy.meta.created = os.time()
    return TS.Dialogues.Save(copy, author, 0)
end

function TS.Dialogues.Rename(id, newid, author)
    local ok, err = TS.Dialogues.Duplicate(id, newid, author)
    if not ok then
        return false, err
    end
    local removed, removeError = TS.Dialogues.Delete(id)
    if not removed then
        return false, removeError
    end
    return true
end

hook.Add("Initialize", "Talksmith.Load", function()
    TS.Dialogues.Reload()
    if table.Count(TS.Dialogues.Registry) == 0 and (TS.Storage.DialogueFileCount or 0) == 0 then
        local function sampleOption(text, nextNode)
            return {
                text = text,
                next = nextNode,
                next_random = {},
                gesture = "",
                conditions = {},
                actions = {},
            }
        end
        local d = TS.Dialogues.New("welcome", "Talksmith")
        d.meta.title = "Добро пожаловать"
        d.settings.actor_name = "Эмметт"
        d.settings.actor_subtitle = "Странник и картограф"
        d.nodes.greeting.text =
            "Некоторые улицы не отмечены на картах. Там и прячутся настоящие истории."
        d.nodes.greeting.options = {
            sampleOption("Что вы обнаружили?", "discovery"),
            sampleOption("Расскажите о своей работе.", "work"),
            sampleOption("Я не буду мешать."),
        }
        d.nodes.discovery = {
            editor = { x = 470, y = 100 },
            text = "Старые проходы меняются чаще, чем люди успевают обновлять карты. Я отмечаю то, что ещё держится.",
            sound = "",
            gesture = "",
            actions = {},
            options = {
                sampleOption("Спасибо."),
                sampleOption("Расскажите о работе.", "work"),
            },
        }
        d.nodes.work = {
            editor = { x = 470, y = 300 },
            text = "Я записываю безопасные маршруты и истории тех, кто их нашёл.",
            sound = "",
            gesture = "",
            actions = {},
            options = { sampleOption("До встречи.") },
        }
        local saved, reason = TS.Dialogues.Save(d, "Talksmith", 0)
        if not saved then
            TS.Logging.Log(0, "Could not create welcome dialogue: " .. tostring(reason))
        end
    end
end)
