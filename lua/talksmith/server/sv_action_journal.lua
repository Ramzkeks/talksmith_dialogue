local TS = Talksmith

local ROOT = "talksmith/action_journal"
local MAX_FILE_BYTES = 524288
local MAX_RECORDS = 512

TS.Runtime.ActionJournal = TS.Runtime.ActionJournal or {}
TS.Runtime.ActionJournal.Cache = TS.Runtime.ActionJournal.Cache or {}
TS.Runtime.ActionJournal.LoadErrors = TS.Runtime.ActionJournal.LoadErrors or {}

file.CreateDir("talksmith")
file.CreateDir(ROOT)

local function playerID(player)
    if not IsValid(player) then
        return nil
    end
    local id = tostring(player:SteamID64() or "")
    return id:match("^%d+$") and id or nil
end

local function journalPath(id)
    return ROOT .. "/" .. id .. ".json"
end

local function validRecord(record)
    if not istable(record)
        or not isstring(record.dialogue)
        or TS.Utils.SafeID(record.dialogue) ~= record.dialogue
        or not isnumber(record.revision)
        or record.revision ~= record.revision
        or record.revision == math.huge
        or record.revision == -math.huge
        or record.revision < 0
        or record.revision ~= math.floor(record.revision)
        or not isnumber(record.count)
        or record.count < 2
        or record.count > math.Clamp(math.floor(tonumber(TS.Config.max_action_entries) or 16), 2, 64)
        or record.count ~= math.floor(record.count)
        or not istable(record.states)
        or not isnumber(record.updated)
        or record.updated ~= record.updated
        or record.updated == math.huge
        or record.updated == -math.huge
    then
        return false
    end
    for index, state in pairs(record.states) do
        local numericIndex = tonumber(index)
        if not numericIndex
            or numericIndex < 1
            or numericIndex > record.count
            or numericIndex ~= math.floor(numericIndex)
            or state ~= "running" and state ~= "done" and state ~= "failed"
        then
            return false
        end
    end
    return true
end

local function sanitize(records)
    if not istable(records) or table.Count(records) > MAX_RECORDS then
        return nil
    end
    local clean = {}
    for key, record in pairs(records) do
        if not isstring(key) or not key:match("^[0-9a-f]+$") or #key ~= 64 or not validRecord(record) then
            return nil
        end
        clean[key] = record
    end
    return clean
end

local function loadJournal(player)
    local id = playerID(player)
    if not id or TS.Runtime.ActionJournal.LoadErrors[id] then
        return nil
    end
    if TS.Runtime.ActionJournal.Cache[id] then
        return TS.Runtime.ActionJournal.Cache[id], id
    end

    local target = journalPath(id)
    if not file.Exists(target, "DATA") then
        TS.Runtime.ActionJournal.Cache[id] = {}
        return TS.Runtime.ActionJournal.Cache[id], id
    end

    local raw = file.Read(target, "DATA")
    if not isstring(raw) or #raw > MAX_FILE_BYTES then
        TS.Runtime.ActionJournal.LoadErrors[id] = true
        TS.Logging.Log(0, "Rejected action journal " .. target .. ": file is too large")
        return nil
    end
    local parsed, decoded = pcall(util.JSONToTable, raw, false, true)
    local clean = parsed and sanitize(decoded) or nil
    if not clean then
        TS.Runtime.ActionJournal.LoadErrors[id] = true
        TS.Logging.Log(0, "Rejected action journal " .. target .. ": invalid JSON")
        return nil
    end
    TS.Runtime.ActionJournal.Cache[id] = clean
    return clean, id
end

local function saveJournal(id, records)
    local raw = util.TableToJSON(records, true)
    if not raw or #raw > MAX_FILE_BYTES then
        return false
    end
    return file.Write(journalPath(id), raw) == true
end

local function canonicalEntries(entries)
    local parts = {}
    local function append(value)
        value = tostring(value)
        parts[#parts + 1] = tostring(#value) .. ":" .. value
    end
    for index, entry in ipairs(entries) do
        if not istable(entry) or not isstring(entry.id) or not istable(entry.params or {}) then
            return nil
        end
        append(index)
        append(entry.id)
        local keys = {}
        for key in pairs(entry.params or {}) do
            if not isstring(key) then return nil end
            keys[#keys + 1] = key
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local value = entry.params[key]
            local valueType = type(value)
            if valueType == "number" then
                value = string.format("%.17g", value)
            elseif valueType == "boolean" then
                value = value and "true" or "false"
            elseif valueType == "string" then
                value = value
            else
                return nil
            end
            append(key)
            append(valueType)
            append(value)
        end
    end
    return table.concat(parts)
end

local function transactionKey(context, entries)
    local document = context.session and context.session.doc or nil
    local dialogue = document and TS.Utils.SafeID(document.id or "")
    local revision = document and document.meta and tonumber(document.meta.revision)
    local scope = isstring(context.action_scope) and context.action_scope or "unknown"
    local encoded = canonicalEntries(entries)
    if not dialogue or not revision or not encoded then
        return nil
    end
    local fingerprint = table.concat({
        tostring(#dialogue), ":", dialogue,
        tostring(#tostring(revision)), ":", tostring(revision),
        tostring(#scope), ":", scope,
        tostring(#encoded), ":", encoded,
    })
    return util.SHA256(fingerprint), dialogue, revision
end

local function pruneObsolete(records)
    local changed = false
    for key, record in pairs(records) do
        local document = TS.Dialogues.Get(record.dialogue)
        local revision = document and document.meta and tonumber(document.meta.revision)
        if not document or revision ~= tonumber(record.revision) then
            records[key] = nil
            changed = true
        end
    end
    return changed
end

function TS.Runtime.ActionJournal.Begin(context, entries)
    if not istable(entries) or #entries <= 1 then
        return { enabled = false }
    end

    local records, id = loadJournal(context.player)
    local key, dialogue, revision = transactionKey(context, entries)
    if not records or not id or not key then
        return nil, "journal_unavailable"
    end
    if pruneObsolete(records) and not saveJournal(id, records) then
        return nil, "journal_unavailable"
    end

    local record = records[key]
    if record then
        local blocked = false
        local changed = false
        for index, state in pairs(record.states) do
            if state == "running" then
                record.states[index] = "failed"
                blocked = true
                changed = true
            elseif state == "failed" then
                blocked = true
            end
        end
        if blocked then
            if changed then
                record.updated = os.time()
                if not saveJournal(id, records) then
                    return nil, "journal_unavailable"
                end
            end
            return nil, "previous_action_failure"
        end

        local complete = true
        for index = 1, record.count do
            if record.states[tostring(index)] ~= "done" then
                complete = false
                break
            end
        end
        if complete then
            records[key] = nil
            if not saveJournal(id, records) then
                records[key] = record
                return nil, "journal_unavailable"
            end
            return { enabled = false, complete = true }
        end

        for index = 1, record.count do
            if record.states[tostring(index)] ~= "done" then
                record.states[tostring(index)] = "running"
                record.updated = os.time()
                if not saveJournal(id, records) then
                    return nil, "journal_unavailable"
                end
                break
            end
        end
    else
        if table.Count(records) >= MAX_RECORDS then
            return nil, "journal_full"
        end
        record = {
            dialogue = dialogue,
            revision = revision,
            count = #entries,
            states = { ["1"] = "running" },
            updated = os.time(),
        }
        records[key] = record
        if not saveJournal(id, records) then
            records[key] = nil
            return nil, "journal_unavailable"
        end
    end

    return {
        enabled = true,
        id = id,
        key = key,
        records = records,
        record = record,
    }
end

function TS.Runtime.ActionJournal.Mark(transaction, index, state)
    if not transaction or transaction.enabled ~= true then
        return true
    end
    if state ~= "running" and state ~= "done" and state ~= "failed" then
        return false
    end
    if not isnumber(index)
        or index < 1
        or index > transaction.record.count
        or index ~= math.floor(index)
    then
        return false
    end
    transaction.record.states[tostring(index)] = state
    transaction.record.updated = os.time()
    return true
end

function TS.Runtime.ActionJournal.Complete(transaction)
    if not transaction or transaction.enabled ~= true then
        return true
    end
    local record = transaction.records[transaction.key]
    transaction.records[transaction.key] = nil
    if not saveJournal(transaction.id, transaction.records) then
        transaction.records[transaction.key] = record
        return false
    end
    return true
end

hook.Add("PlayerDisconnected", "Talksmith.ActionJournalCache", function(player)
    local id = playerID(player)
    if id then
        TS.Runtime.ActionJournal.Cache[id] = nil
        TS.Runtime.ActionJournal.LoadErrors[id] = nil
    end
end)
