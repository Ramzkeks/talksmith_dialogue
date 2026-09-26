local TS = Talksmith

local ROOT = "talksmith/flags"
TS.Storage.Flags = TS.Storage.Flags or {}
TS.Storage.FlagLoadErrors = TS.Storage.FlagLoadErrors or {}
file.CreateDir("talksmith")
file.CreateDir(ROOT)

local function maxFileBytes()
    return math.Clamp(math.floor(tonumber(TS.Config.max_flag_file_bytes) or 131072), 4096, 1048576)
end

local function maxFlags()
    return math.Clamp(math.floor(tonumber(TS.Config.max_flags_per_player) or 256), 16, 4096)
end

local function playerID(player)
    if not IsValid(player) then
        return nil
    end
    local value = tostring(player:SteamID64() or "")
    return value:match("^%d+$") and value or nil
end

local function path(id)
    return ROOT .. "/" .. id .. ".json"
end

local function validValue(value)
    if isnumber(value) then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    return isbool(value) or isstring(value) and TS.Utils._UTF8Length(value) <= 256
end

local function sanitize(values)
    if not istable(values) then
        return nil
    end
    if table.Count(values) > maxFlags() then
        return nil
    end
    local clean = {}
    for key, value in pairs(values) do
        local safeKey = TS.Utils.SafeID(key)
        if safeKey ~= key or not validValue(value) then
            return nil
        end
        clean[safeKey] = value
    end
    return clean
end

function TS.Storage.LoadFlags(player)
    local id = playerID(player)
    if not id then
        return nil
    end
    if TS.Storage.Flags[id] then
        return TS.Storage.Flags[id]
    end
    if TS.Storage.FlagLoadErrors[id] then
        return nil
    end

    local target = path(id)
    if not file.Exists(target, "DATA") then
        TS.Storage.Flags[id] = {}
        return TS.Storage.Flags[id]
    end

    local raw = file.Read(target, "DATA")
    if not isstring(raw) or #raw > maxFileBytes() then
        TS.Storage.FlagLoadErrors[id] = true
        TS.Logging.Log(0, "Rejected player flag file " .. target .. ": file is too large")
        return nil
    end
    local parsed, decoded = pcall(util.JSONToTable, raw or "", false, true)
    if not parsed or not istable(decoded) then
        TS.Storage.FlagLoadErrors[id] = true
        TS.Logging.Log(0, "Rejected player flag file " .. target .. ": invalid JSON")
        return nil
    end

    local clean = sanitize(decoded)
    if not clean then
        TS.Storage.FlagLoadErrors[id] = true
        TS.Logging.Log(0, "Rejected player flag file " .. target .. ": invalid flag data")
        return nil
    end
    TS.Storage.Flags[id] = clean
    return TS.Storage.Flags[id]
end

function TS.Storage.SaveFlags(player)
    local id = playerID(player)
    local values = id and TS.Storage.Flags[id]
    if not id or not istable(values) then
        return false
    end
    local json = util.TableToJSON(values, true)
    if not json or #json > maxFileBytes() or table.Count(values) > maxFlags() then
        return false
    end
    return TS.Utils.WriteDataFile(path(id), json)
end

-- Commit related objective flags in one write, or restore the whole set.
function TS.Storage.SetFlags(player, updates)
    local values = TS.Storage.LoadFlags(player)
    if not values or not istable(updates) then return false end
    local previous = table.Copy(values)
    for key, value in pairs(updates) do
        if TS.Utils.SafeID(key) ~= key or not validValue(value) then return false end
    end
    for key, value in pairs(updates) do values[key] = value end
    if not TS.Storage.SaveFlags(player) then
        table.Empty(values)
        for key, value in pairs(previous) do values[key] = value end
        return false
    end
    return true
end

function TS.Storage.SetFlag(player, key, value)
    key = TS.Utils.SafeID(key or "")
    local values = key and TS.Storage.LoadFlags(player)
    if not values or not validValue(value) then
        return false
    end

    local previous = values[key]
    if previous == nil and table.Count(values) >= maxFlags() then
        return false
    end
    values[key] = value
    if not TS.Storage.SaveFlags(player) then
        values[key] = previous
        return false
    end
    return true
end

function TS.Storage.GetFlag(player, key, fallback)
    key = TS.Utils.SafeID(key or "")
    local values = key and TS.Storage.LoadFlags(player)
    if not values then
        return fallback, false
    end
    local value = values[key]
    if value == nil then
        return fallback, true
    end
    return value, true
end

function TS.Storage.ClearFlag(player, key)
    key = TS.Utils.SafeID(key or "")
    local values = key and TS.Storage.LoadFlags(player)
    if not values then
        return false
    end

    local previous = values[key]
    values[key] = nil
    if not TS.Storage.SaveFlags(player) then
        values[key] = previous
        return false
    end
    return true
end

hook.Add("PlayerDisconnected", "Talksmith.FlagCache", function(player)
    local id = playerID(player)
    if id then
        TS.Storage.Flags[id] = nil
        TS.Storage.FlagLoadErrors[id] = nil
    end
end)
