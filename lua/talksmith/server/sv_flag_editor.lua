local TS = Talksmith
util.AddNetworkString("ts_flag_editor_request")
util.AddNetworkString("ts_flag_editor_reply")

local function respond(admin, id, data)
    data.id = id
    net.Start("ts_flag_editor_reply")
    net.WriteString(util.TableToJSON(data))
    net.Send(admin)
end

net.Receive("ts_flag_editor_request", function(bits, admin)
    if bits > 32768 or not TS.Network.Allow(admin, "flag_editor", 0.15) then
        return
    end
    local raw = net.ReadString()
    local ok, request = pcall(util.JSONToTable, raw, false, true)
    if not ok or not istable(request) then
        return
    end
    local id = tonumber(request.id)
    if not id or id ~= math.floor(id) or id < 0 or id > 2147483647 then
        return
    end
    local function reject(code)
        respond(admin, id, { error = code })
    end
    if not TS.Permissions.CanUseEditor(admin) or not TS.Permissions.Has(admin, "talksmith.flags.view") then
        return reject("denied")
    end
    local editable = TS.Permissions.Has(admin, "talksmith.flags.manage")
    if request.op == "players" then
        local rows = {}
        for _, target in ipairs(player.GetAll()) do
            if not target:IsBot() then
                rows[#rows + 1] = { sid = target:SteamID64(), name = TS.Utils.ClampString(target:Nick(), 64) }
            end
        end
        return respond(admin, id, { players = rows, editable = editable })
    end
    if request.op ~= "list" and request.op ~= "set" and request.op ~= "delete" then
        return reject("invalid")
    end
    local target
    for _, candidate in ipairs(player.GetAll()) do
        if not candidate:IsBot() and candidate:SteamID64() == request.sid then
            target = candidate
            break
        end
    end
    if not IsValid(target) then
        return reject("offline")
    end
    local values = TS.Storage.LoadFlags(target)
    if not values then
        return reject("storage")
    end
    if request.op ~= "list" then
        if not editable then
            return reject("denied")
        end
        -- Editing quest state during a live scene can be overwritten by its outcome.
        if TS.Runtime.GetSession(target) or TS.VJ and TS.VJ.Attempts and TS.VJ.Attempts[target] then
            return reject("busy")
        end
        local key = request.key
        if not isstring(key) or TS.Utils.SafeID(key) ~= key then
            return reject("invalid")
        end
        local current = values[key]
        -- Compare-and-set prevents overwriting newer game/admin changes.
        if request.exists ~= (current ~= nil) or current ~= request.previous then
            return reject("conflict")
        end
        local saved
        if request.op == "delete" then
            saved = TS.Storage.ClearFlag(target, key)
        else
            local value = request.value
            if
                not (
                    isbool(value)
                    or isstring(value) and TS.Utils._UTF8Length(value) <= 256
                    or isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
                )
            then
                return reject("invalid")
            end
            saved = TS.Storage.SetFlag(target, key, value)
        end
        if not saved then
            return reject("storage")
        end
        TS.Logging.Log(
            1,
            "Flag editor: " .. admin:SteamID64() .. " " .. request.op .. " " .. key .. " for " .. target:SteamID64()
        )
    end
    local query = isstring(request.query) and string.lower(string.sub(request.query, 1, 128)) or ""
    local keys = {}
    for key, value in pairs(values) do
        if (not request.onlyTrue or value == true) and string.find(string.lower(key), query, 1, true) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local page = tonumber(request.page) or 1
    if page ~= page or page == math.huge or page == -math.huge then
        page = 1
    end
    local pages = math.max(1, math.ceil(#keys / 24))
    page = math.Clamp(math.floor(page), 1, pages)
    local rows = {}
    for index = (page - 1) * 24 + 1, math.min(page * 24, #keys) do
        local key = keys[index]
        rows[#rows + 1] = { key = key, value = values[key] }
    end
    respond(admin, id, {
        sid = target:SteamID64(),
        rows = rows,
        page = page,
        pages = pages,
        total = #keys,
        editable = editable,
        saved = request.op ~= "list",
    })
end)
