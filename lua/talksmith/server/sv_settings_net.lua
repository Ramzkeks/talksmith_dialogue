local TS = Talksmith

local SETTINGS_FILE = "talksmith/settings.json"
local MAX_PAYLOAD = 262144
local MAX_NET_PAYLOAD = 60000
local MAX_VALUE_PAYLOAD = 256

local SERVER_SETTINGS = {
    dialogue_speed = { kind = "number", min = 0.25, max = 4 },
    show_name = { kind = "boolean" },
    show_description = { kind = "boolean" },
    show_interaction = { kind = "boolean" },
    autosave_actors = { kind = "boolean" },
    backups = { kind = "number", min = 0, max = 50, integer = true },
    logging = { kind = "number", min = -1, max = 1, integer = true },
}

local RUNTIME_SETTINGS = {
    dialogue_speed = true,
    show_name = true,
    show_description = true,
    show_interaction = true,
}

for _, name in ipairs({
    "ts_settings_request",
    "ts_settings_update",
    "ts_server_setting_update",
    "ts_permission_setting_update",
    "ts_settings_data",
    "ts_runtime_settings",
}) do
    util.AddNetworkString(name)
end

local function finiteNumber(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

local function validateSetting(key, value)
    local rule = SERVER_SETTINGS[key]
    if not rule then
        return nil
    end

    if rule.kind == "boolean" then
        if isbool(value) then
            return value
        end
        return nil
    end

    if rule.kind == "number" then
        if not finiteNumber(value) or value < rule.min or value > rule.max then
            return nil
        end
        if rule.integer and value ~= math.floor(value) then
            return nil
        end
        return value
    end

    return nil
end

local function serverSettings()
    if TS.Config.logging ~= -1 and (not TS.Logging.IsAvailable or not TS.Logging.IsAvailable()) then
        TS.Config.logging = -1
    end

    local settings = {}
    for key in pairs(SERVER_SETTINGS) do
        settings[key] = TS.Config[key]
    end
    return settings
end

local function integrationSettings()
    local settings = {}
    for id, integration in pairs(TS.Integrations.Registry) do
        if integration.automatic ~= true then
            settings[id] = TS.Config.integrations[id] == true
        end
    end
    return settings
end

local function permissionSettings()
    local settings = {}
    for _, right in ipairs(TS.Permissions.Rights or {}) do
        local group = TS.Config.permission_groups[right]
        if isstring(group) then
            group = string.Trim(group)
        end
        if not isstring(group) or group == "" or #group > 64 or string.find(group, "%c") then
            group = "superadmin"
        end
        settings[right] = group
    end
    return settings
end

function TS.Config.GetServerSettings()
    return serverSettings()
end

function TS.Config.Save()
    if TS.Storage.SettingsWritable == false then
        return false
    end

    file.CreateDir("talksmith")
    local json = util.TableToJSON({
        schema = 1,
        server = serverSettings(),
        integrations = integrationSettings(),
        permissions = permissionSettings(),
    }, true)
    if not json then
        return false
    end

    return file.Write(SETTINGS_FILE, json) == true
end

local broadcastRuntimeSettings

function TS.Config.Load()
    local savedServer = {}
    local savedIntegrations = {}
    local savedPermissions = {}

    if file.Exists(SETTINGS_FILE, "DATA") then
        local raw = file.Read(SETTINGS_FILE, "DATA")
        local withinLimit = isstring(raw) and #raw <= MAX_PAYLOAD
        local parsed, decoded = false, nil
        if withinLimit then
            parsed, decoded = pcall(util.JSONToTable, raw, false, true)
        end
        local valid = withinLimit and parsed
            and istable(decoded)
            and decoded.schema == 1
            and istable(decoded.server)
            and istable(decoded.integrations)
            and (decoded.permissions == nil or istable(decoded.permissions))
        if valid then
            for key, value in pairs(decoded.server) do
                if not SERVER_SETTINGS[key] or validateSetting(key, value) == nil then
                    valid = false
                    break
                end
            end
        end
        if valid then
            for id, enabled in pairs(decoded.integrations) do
                if TS.Utils.SafeID(id) ~= id or not isbool(enabled) then
                    valid = false
                    break
                end
            end
        end
        if valid then
            for right, group in pairs(decoded.permissions or {}) do
                if not TS.Permissions.IsKnown(right)
                    or not isstring(group)
                    or group == ""
                    or #group > 64
                    or string.find(group, "%c")
                then
                    valid = false
                    break
                end
            end
        end
        if valid then
            savedServer = decoded.server
            savedIntegrations = decoded.integrations
            savedPermissions = decoded.permissions or {}
            TS.Storage.SettingsWritable = true
        else
            TS.Storage.SettingsWritable = false
            TS.Logging.Log(0, "Rejected " .. SETTINGS_FILE .. ": invalid settings JSON")
        end
    else
        TS.Storage.SettingsWritable = true
    end

    for key in pairs(SERVER_SETTINGS) do
        local value = savedServer[key]
        if value == nil then
            value = TS.Config[key]
        end
        local valid = validateSetting(key, value)
        if valid == nil then
            valid = validateSetting(key, TS.Config.Defaults[key])
        end
        if valid ~= nil then
            TS.Config[key] = valid
        end
    end

    for id in pairs(TS.Integrations.Registry) do
        local integration = TS.Integrations.Registry[id]
        if integration.automatic == true then
            TS.Config.integrations[id] = nil
        else
            local enabled = savedIntegrations[id]
            if enabled == nil then
                enabled = TS.Config.integrations[id] == true
            end
            TS.Config.integrations[id] = enabled == true
        end
    end

    for _, right in ipairs(TS.Permissions.Rights or {}) do
        local group = savedPermissions[right]
        if not isstring(group) then
            group = TS.Config.permission_groups[right]
        end
        if not isstring(group) or group == "" or #group > 64 or string.find(group, "%c") then
            group = "superadmin"
        end
        TS.Config.permission_groups[right] = string.Trim(group)
    end

    TS.Integrations.RefreshAll()
    if TS.Config.logging ~= -1 and (not TS.Logging.IsAvailable or not TS.Logging.IsAvailable()) then
        TS.Config.logging = -1
    end
    if broadcastRuntimeSettings then
        broadcastRuntimeSettings()
    end
end

function TS.Integrations.SetEnabled(id, enabled)
    id = TS.Utils.SafeID(id)
    if not id or not TS.Integrations.Registry[id] then
        return false, "unknown_integration"
    end
    if TS.Integrations.Registry[id].automatic == true then
        return false, "automatic_integration"
    end

    local previous = TS.Config.integrations[id] == true
    TS.Config.integrations[id] = enabled == true
    local ok, status, reason = TS.Integrations.Refresh(id)
    if not ok or not TS.Config.Save() then
        TS.Config.integrations[id] = previous
        TS.Integrations.Refresh(id)
        return false, "save_failed"
    end

    hook.Run("Talksmith.IntegrationSettingChanged", id, enabled == true, status, reason)
    return true
end

function TS.Config.Set(key, value)
    local valid = validateSetting(key, value)
    if valid == nil then
        return false, "invalid_setting"
    end
    if key == "logging" and valid ~= -1 and (not TS.Logging.IsAvailable or not TS.Logging.IsAvailable()) then
        return false, "logging_unavailable"
    end

    local previous = TS.Config[key]
    if previous == valid then
        return true
    end

    TS.Config[key] = valid
    if not TS.Config.Save() then
        TS.Config[key] = previous
        return false, "save_failed"
    end

    if RUNTIME_SETTINGS[key] and broadcastRuntimeSettings then
        broadcastRuntimeSettings()
    end
    hook.Run("Talksmith.ConfigChanged", key, valid, previous)
    return true
end

function TS.Config.SetPermissionGroup(right, group, actor)
    local previous = TS.Config.permission_groups[right]
    local ok, code = TS.Permissions.SetConfiguredGroup(right, group)
    if not ok then
        return false, code
    end

    local current = TS.Config.permission_groups[right]
    if not TS.Config.Save() then
        TS.Config.permission_groups[right] = previous
        return false, "save_failed"
    end

    hook.Run("Talksmith.PermissionSettingChanged", right, current, actor)
    return true
end

local function writeRuntimeSettings()
    net.WriteFloat(math.Clamp(tonumber(TS.Config.dialogue_speed) or 1, 0.25, 4))
    net.WriteBool(TS.Config.show_name == true)
    net.WriteBool(TS.Config.show_description == true)
    net.WriteBool(TS.Config.show_interaction == true)
end

function TS.Network.SendRuntimeSettings(player)
    if not IsValid(player) then
        return false
    end
    net.Start("ts_runtime_settings")
    writeRuntimeSettings()
    net.Send(player)
    return true
end

broadcastRuntimeSettings = function()
    net.Start("ts_runtime_settings")
    writeRuntimeSettings()
    net.Broadcast()
end

local function sendSettings(player, result, code)
    local backendID, backendName = TS.Permissions.GetAdminBackend()
    local data = {
        api_version = TS.API.IntegrationVersion,
        can_manage_settings = TS.Permissions.Has(player, "talksmith.settings.manage"),
        can_manage_integrations = TS.Permissions.Has(player, "talksmith.integrations.manage"),
        can_manage_permissions = TS.Permissions.Has(player, "talksmith.settings.manage"),
        permissions_available = backendID ~= nil,
        permission_backend = backendID or "",
        permission_backend_name = backendName or "",
        permission_groups = backendID and TS.Permissions.GetGroupCatalog() or {},
        permissions = backendID and TS.Permissions.GetSettings() or {},
        logging_available = TS.Logging.IsAvailable and TS.Logging.IsAvailable() or false,
        settings = serverSettings(),
        integrations = TS.Integrations.GetCatalog(),
        result = result ~= false,
        code = code or "",
    }
    local json = util.TableToJSON(data) or "{}"
    local payload = util.Compress(json)

    if not payload or #payload > MAX_NET_PAYLOAD then
        return false
    end

    net.Start("ts_settings_data")
    net.WriteUInt(#payload, 19)
    net.WriteData(payload, #payload)
    net.Send(player)
    return true
end

local function broadcastSettings(actor, result, code)
    for _, recipient in ipairs(player.GetAll()) do
        if recipient == actor or TS.Permissions.Has(recipient, "talksmith.editor.open") then
            local isActor = recipient == actor
            sendSettings(recipient, not isActor or result, isActor and code or "")
        end
    end
end

TS.Network.BroadcastSettings = broadcastSettings

net.Receive("ts_settings_request", function(len, player)
    if len > 8 or not TS.Network.Allow(player, "settings_request", 0.35) or not TS.Permissions.CanUseEditor(player) then
        return
    end
    sendSettings(player)
end)

net.Receive("ts_settings_update", function(len, player)
    if len > 600
        or not TS.Network.Allow(player, "settings_update", 0.35)
        or not TS.Permissions.CanUseEditor(player, "talksmith.integrations.manage")
    then
        return
    end

    local id = TS.Utils.SafeID(net.ReadString() or "")
    local enabled = net.ReadBool()
    local ok, code = TS.Integrations.SetEnabled(id, enabled)
    broadcastSettings(player, ok, code)
end)

net.Receive("ts_server_setting_update", function(len, player)
    if len > 2800
        or not TS.Network.Allow(player, "server_setting_update", 0.2)
        or not TS.Permissions.CanUseEditor(player, "talksmith.settings.manage")
    then
        return
    end

    local key = net.ReadString() or ""
    local raw = net.ReadString() or ""
    if not SERVER_SETTINGS[key] or #raw <= 0 or #raw > MAX_VALUE_PAYLOAD then
        broadcastSettings(player, false, "invalid_setting")
        return
    end

    local parsed, decoded = pcall(util.JSONToTable, raw)
    if not parsed or not istable(decoded) or decoded.value == nil then
        broadcastSettings(player, false, "invalid_setting")
        return
    end

    local ok, code = TS.Config.Set(key, decoded.value)
    broadcastSettings(player, ok, code)
end)

net.Receive("ts_permission_setting_update", function(len, player)
    if len > 1400
        or not TS.Network.Allow(player, "permission_setting_update", 0.25)
        or not TS.Permissions.CanUseEditor(player, "talksmith.settings.manage")
        or not TS.Permissions.HasAdminBackend()
    then
        return
    end

    local right = net.ReadString() or ""
    local group = net.ReadString() or ""
    if #right <= 0
        or #right > 96
        or #group <= 0
        or #group > 64
        or not TS.Permissions.IsKnown(right)
    then
        broadcastSettings(player, false, "invalid_permission")
        return
    end

    local ok, code = TS.Config.SetPermissionGroup(right, group, player)
    broadcastSettings(player, ok, code)
end)

hook.Add("PlayerInitialSpawn", "Talksmith.RuntimeSettingsSync", function(player)
    timer.Simple(1, function()
        if IsValid(player) then
            TS.Network.SendRuntimeSettings(player)
        end
    end)
end)

hook.Add("Talksmith.AdminGroupsChanged", "Talksmith.RefreshPermissionSettings", function()
    timer.Create("Talksmith.PermissionSettingsRefresh", 0.1, 1, function()
        if TS.Network.BroadcastSettings then
            TS.Network.BroadcastSettings(nil, true, "")
        end
    end)
end)

timer.Simple(0, function()
    TS.Config.Load()
end)
