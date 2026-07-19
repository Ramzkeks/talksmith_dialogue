local TS = Talksmith
local function path()
    return "talksmith/actors/" .. game.GetMap() .. ".json"
end
file.CreateDir("talksmith/actors")

local function isArray(value)
    if not istable(value) then
        return false
    end
    local count = 0
    for key in pairs(value) do
        if not isnumber(key) or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
    end
    return count == #value
end

local function isNumberTriple(value)
    if not istable(value) or #value ~= 3 then
        return false
    end
    for index = 1, 3 do
        local number = value[index]
        if not isnumber(number)
            or number ~= number
            or number == math.huge
            or number == -math.huge
            or math.abs(number) > 1000000
        then
            return false
        end
    end
    return true
end

function TS.Actors.SaveLayout()
    if TS.Storage.ActorLayoutWritable == false then
        TS.Logging.Log(0, "Actor layout was not saved because its JSON failed to load")
        return false, "load_failed"
    end

    local out = {}
    for _, e in ipairs(TS.Actors.GetAll()) do
        if e.Persistent then
            local p, a = e:GetPos(), e:GetAngles()
            out[#out + 1] = {
                model = e:GetModel(),
                model_override = e.ModelOverride == true,
                pos = { p.x, p.y, p.z },
                ang = { a.p, a.y, a.r },
                name = TS.Actors.GetName(e),
                subtitle = TS.Actors.GetSubtitle(e),
                dialogue = TS.Actors.GetDialogue(e),
            }
        end
    end
    for _, v in ipairs(TS.Storage.DeferredActors or {}) do
        out[#out + 1] = v
    end

    local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_actors) or 128), 1, 2048)
    if #out > maximum then
        TS.Logging.Log(0, "Actor layout was not saved because it exceeds max_actors")
        return false, "actor_limit"
    end

    local json = util.TableToJSON(out, true)
    local maxBytes = math.Clamp(math.floor(tonumber(TS.Config.max_actor_layout_bytes) or 1048576), 65536, 8388608)
    if not json or #json > maxBytes then
        TS.Logging.Log(0, "Actor layout could not be encoded as JSON")
        return false, "too_large"
    end
    if file.Write(path(), json) ~= true then
        TS.Logging.Log(0, "Actor layout could not be written to " .. path())
        return false, "write_failed"
    end
    return #out
end

function TS.Actors.LoadLayout()
    local target = path()
    local entries = {}
    if file.Exists(target, "DATA") then
        local raw = file.Read(target, "DATA")
        local maxBytes = math.Clamp(math.floor(tonumber(TS.Config.max_actor_layout_bytes) or 1048576), 65536, 8388608)
        if not isstring(raw) or #raw > maxBytes then
            TS.Storage.ActorLayoutWritable = false
            TS.Logging.Log(0, "Rejected Actor layout " .. target .. ": file is too large")
            return false, "too_large"
        end
        local parsed, decoded = pcall(util.JSONToTable, raw or "", false, true)
        if not parsed or not isArray(decoded) then
            TS.Storage.ActorLayoutWritable = false
            TS.Logging.Log(0, "Rejected Actor layout " .. target .. ": invalid JSON")
            return false, "invalid_json"
        end
        local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_actors) or 128), 1, 2048)
        if #decoded > maximum then
            TS.Storage.ActorLayoutWritable = false
            TS.Logging.Log(0, "Rejected Actor layout " .. target .. ": too many Actors")
            return false, "actor_limit"
        end
        entries = decoded
    end

    TS.Storage.ActorLayoutWritable = true
    for _, e in ipairs(TS.Actors.GetAll()) do
        if e.Persistent then
            e:Remove()
        end
    end
    TS.Storage.DeferredActors = {}
    local spawned, deferred = 0, 0
    for _, v in ipairs(entries) do
        local dialogue = istable(v) and TS.Utils.SafeID(v.dialogue or "")
        local wellFormed = istable(v)
            and dialogue == v.dialogue
            and isNumberTriple(v.pos)
            and (v.ang == nil or isNumberTriple(v.ang))
        if wellFormed and TS.Utils.IsModelAllowed(v.model) and TS.Dialogues.Get(dialogue) then
            local a = istable(v.ang) and v.ang or { 0, 0, 0 }
            local actor = TS.Actors.Spawn({
                model = v.model,
                model_override = v.model_override == true,
                pos = Vector(tonumber(v.pos[1]) or 0, tonumber(v.pos[2]) or 0, tonumber(v.pos[3]) or 0),
                ang = Angle(tonumber(a[1]) or 0, tonumber(a[2]) or 0, tonumber(a[3]) or 0),
                name = TS.Utils.ClampString(v.name, 128),
                subtitle = TS.Utils.ClampString(v.subtitle, 128),
                dialogue = dialogue,
            })
            if IsValid(actor) then
                spawned = spawned + 1
            else
                TS.Storage.DeferredActors[#TS.Storage.DeferredActors + 1] = v
                deferred = deferred + 1
            end
        else
            TS.Storage.DeferredActors[#TS.Storage.DeferredActors + 1] = v
            deferred = deferred + 1
        end
    end
    if deferred > 0 then
        TS.Logging.Log(0, "Preserved " .. deferred .. " Actor layout record(s) that could not be spawned")
    end
    return true, spawned, deferred
end

function TS.Actors.LoadConfigured()
    for _, e in ipairs(TS.Actors.GetAll()) do
        if e.CodeConfigured then
            e:Remove()
        end
    end
    local count = 0
    for key, definition in pairs(TS.Config.spawns or {}) do
        if istable(definition) and TS.Utils.MapMatches(definition.map) then
            local data = TS.Utils.Copy(definition)
            data.code_key = tostring(key)
            local actor = TS.Actors.Create(data)
            if IsValid(actor) then
                count = count + 1
            else
                TS.Logging.Log(0, "Rejected configured Actor spawn: " .. tostring(key))
            end
        end
    end
    return count
end

hook.Add("InitPostEntity", "Talksmith.RestoreActors", function()
    timer.Simple(0, TS.Actors.LoadLayout)
    timer.Simple(0.1, TS.Actors.LoadConfigured)
end)
hook.Add("ShutDown", "Talksmith.SaveActors", function()
    if TS.Config.autosave_actors then
        TS.Actors.SaveLayout()
    end
end)
