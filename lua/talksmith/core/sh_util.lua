local TS = Talksmith
function TS.Utils.SafeID(v)
    if not isstring(v) then
        return nil
    end
    v = v:lower()
    if #v < 1 or #v > 64 then
        return nil
    end
    return v:match("^[a-z0-9][a-z0-9_%-]*$") and v or nil
end

function TS.Utils.SafeRefID(v)
    if not isstring(v) then
        return nil
    end
    v = v:lower()
    if #v < 1 or #v > 96 then
        return nil
    end
    return v:match("^[a-z0-9][a-z0-9_%.%-]*$")
        and not v:find("%.%.")
        and not v:find("%.$")
        and v
        or nil
end
function TS.Utils._UTF8Length(value)
    if not isstring(value) then return 0 end
    return utf8.len(utf8.force(value)) or 0
end

function TS.Utils.ClampString(value, maximum)
    if not isstring(value) then return "" end
    maximum = math.max(math.floor(tonumber(maximum) or 0), 0)
    if maximum == 0 then return "" end
    return utf8.sub(utf8.force(value), 1, maximum)
end
function TS.Utils.InList(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then
            return true
        end
    end
    return false
end

local function parseRemoteAudioURL(value)
    if not isstring(value) then
        return nil
    end
    local maxLength = math.Clamp(tonumber(TS.Config.max_remote_audio_url_length) or 2048, 128, 8192)
    if #value < 8 or #value > maxLength or value:find("[%z\1-\32\127]") then
        return nil
    end
    local scheme, authority = string.lower(value):match("^(https?)://([^/%?#]+)")
    if not scheme or not authority or authority == "" or authority:find("@", 1, true) then
        return nil
    end

    if authority:sub(1, 1) == "[" then
        return nil
    end
    local host, port = authority:match("^([a-z0-9%.%-]+):?(%d*)$")
    if not host
        or host == ""
        or host:find("..", 1, true)
        or not host:find(".", 1, true)
        or host:sub(1, 1) == "."
        or host:sub(-1) == "."
        or authority:sub(-1) == ":"
    then
        return nil
    end
    if host:match("^%d+%.%d+%.%d+%.%d+$")
        or host == "localhost"
        or host:sub(-10) == ".localhost"
        or host:sub(-6) == ".local"
        or host:sub(-9) == ".internal"
        or host:sub(-4) == ".lan"
        or host:sub(-10) == ".home.arpa"
    then
        return nil
    end
    if port ~= "" and not (scheme == "http" and port == "80" or scheme == "https" and port == "443") then
        return nil
    end
    local numericAddress = true
    for label in host:gmatch("[^%.]+") do
        local validLabel = label:match("^[a-z0-9]$")
            or label:match("^[a-z0-9][a-z0-9%-]*[a-z0-9]$")
        if #label > 63 or not validLabel then
            return nil
        end
        if not label:match("^%d+$") and not label:match("^0x[0-9a-f]+$") then
            numericAddress = false
        end
    end
    if numericAddress then
        return nil
    end
    return host, scheme
end

function TS.Utils.GetRemoteAudioHost(value)
    return parseRemoteAudioURL(value)
end

function TS.Utils.IsRemoteAudioURL(value)
    return TS.Utils.GetRemoteAudioHost(value) ~= nil
end

local function isDirectMP3URL(value)
    if not isstring(value) then
        return false
    end
    local path = string.lower(value):match("^https?://[^/%?#]+([^%?#]*)")
    return isstring(path) and path:match("%.mp3$") ~= nil
end

function TS.Utils.IsRemoteAudioAllowed(value)
    if TS.Config.remote_audio_enabled ~= true then
        return false
    end
    local host = TS.Utils.GetRemoteAudioHost(value)
    if not host or not isDirectMP3URL(value) then
        return false
    end
    for _, rule in ipairs(TS.Config.allowed_remote_audio_hosts or {}) do
        rule = string.lower(tostring(rule))
        if rule == "*" then
            return true
        end
        if rule == host then
            return true
        end
        if rule:sub(1, 2) == "*." then
            local suffix = rule:sub(2)
            if #host > #suffix and host:sub(-#suffix) == suffix then
                return true
            end
        end
    end
    return false
end

local blockedInventoryClasses = {
    lua_run = true,
    point_servercommand = true,
    point_clientcommand = true,
    point_broadcastclientcommand = true,
    game_end = true,
    env_entity_maker = true,
    talksmith_actor = true,
    worldspawn = true,
}

function TS.Utils.IsInventoryEntityAllowed(provider, class, nativeAllowed)
    provider = TS.Utils.SafeID(provider or "")
    if not provider or not isstring(class) or #class < 1 or #class > 128 then
        return false
    end
    class = class:lower()
    if not class:match("^[a-z0-9_%-]+$") or blockedInventoryClasses[class] then
        return false
    end
    if class:sub(1, 5) == "func_" or class:sub(1, 4) == "npc_" then
        return false
    end

    local configured = istable(TS.Config.allowed_inventory_entities)
        and TS.Config.allowed_inventory_entities
        or {}
    return nativeAllowed == true
        or TS.Utils.InList(configured.common, class)
        or TS.Utils.InList(configured[provider], class)
        or TS.Utils.InList(TS.Config.allowed_weapons, class)
end

function TS.Utils.IsSoundAllowed(value)
    if not isstring(value) then
        return false
    end
    if value == "" then
        return true
    end
    if TS.Utils.IsRemoteAudioURL(value) then
        return TS.Utils.IsRemoteAudioAllowed(value)
    end
    return #value <= 128 and TS.Utils.InList(TS.Config.allowed_sounds, value)
end
function TS.Utils.Copy(v)
    return table.Copy(v or {})
end
function TS.Utils.Now()
    return os.time()
end
function TS.Utils.SafeCall(label, fn, ...)
    local args = { ... }
    local a, b, c
    local ok, err = xpcall(function()
        a, b, c = fn(unpack(args))
    end, debug.traceback)
    if not ok then
        TS.Logging.Log(0, label .. ": " .. tostring(err))
        return false
    end
    return true, a, b, c
end

function TS.Utils.WriteDataFile(path, contents)
    if not isstring(path) or not isstring(contents) then
        return false
    end

    local result = file.Write(path, contents)
    if result == true then
        return true
    end

    return file.Read(path) == contents
end

function TS.Utils.IsModelAllowed(model)
    if not isstring(model) or #model < 5 or #model > 256 then
        return false
    end
    local list = TS.Config.allowed_models
    if istable(list) and #list > 0 and not TS.Utils.InList(list, "*") then
        return TS.Utils.InList(list, model)
    end
    return util.IsValidModel(model) or file.Exists(model, "GAME")
end

function TS.Actors.IsActor(e)
    return IsValid(e) and e:GetClass() == "talksmith_actor"
end

function TS.Actors.GetAll()
    return ents.FindByClass("talksmith_actor")
end

function TS.Actors.GetName(e)
    if not TS.Actors.IsActor(e) then return "" end
    return e:GetActorName()
end

function TS.Actors.GetSubtitle(e)
    if not TS.Actors.IsActor(e) then return "" end
    return e:GetActorSubtitle()
end

function TS.Actors.GetDialogue(e)
    if not TS.Actors.IsActor(e) then return "" end
    return e:GetDialogueID()
end

function TS.Actors.GetNameOffset(e)
    local v = TS.Actors.IsActor(e) and e:GetNameOffset() or 0
    return v > 0 and v or 82
end

function TS.Actors.GetTheme(e)
    local t = TS.Actors.IsActor(e) and e:GetTheme() or ""
    return (isstring(t) and t ~= "") and t or "default"
end

if SERVER then
    function TS.Actors.SetData(e, name, subtitle, dialogue)
        if not TS.Actors.IsActor(e) then return end
        e:SetActorName(name or "")
        e:SetActorSubtitle(subtitle or "")
        e:SetDialogueID(dialogue or "")
    end

    function TS.Actors.SetBusy(e, busy)
        if TS.Actors.IsActor(e) and e.SetBusy then
            e:SetBusy(busy == true)
        end
    end

    function TS.Actors.SetAppearance(e, s)
        if not TS.Actors.IsActor(e) then return end
        s = s or {}
        local theme = isstring(s.theme) and s.theme or "default"
        theme = TS.Utils.InList(TS.Config.allowed_themes, theme) and theme or "default"
        e:SetNameOffset(math.Clamp(tonumber(s.name_offset) or 82, 1, 256))
        e:SetTheme(theme)
        e:SetUseLimit(s.use_limit == true)
    end
end
