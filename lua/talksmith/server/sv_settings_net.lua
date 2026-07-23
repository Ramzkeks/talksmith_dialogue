local TS = Talksmith

local SETTINGS_FILE = "talksmith/settings.json"
local MAX_PAYLOAD = 262144
local MAX_NET_PAYLOAD = 60000
local MAX_VALUE_PAYLOAD = 256
local MAX_ALLOWED_WEAPONS = 256
local MAX_WEAPON_CLASS = 64
local MAX_SUPERADMINS = TS.Permissions.MaxSuperAdmins or 16

TS.Storage.SettingsLoaded = false

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
    "ts_weapon_allowlist_update",
    "ts_permission_setting_update",
    "ts_superadmin_update",
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

local function validateWeaponClass(value)
    if not isstring(value) then
        return nil
    end

    local class = string.Trim(value)
    if #class <= 0
        or #class > MAX_WEAPON_CLASS
        or not string.match(class, "^[a-z][a-z0-9_]*$")
    then
        return nil
    end
    return class
end

local function normalizeWeaponList(value)
    if not istable(value) then
        return nil
    end

    local count = 0
    for key in pairs(value) do
        if not isnumber(key) or key < 1 or key ~= math.floor(key) then
            return nil
        end
        count = count + 1
    end
    if count > MAX_ALLOWED_WEAPONS then
        return nil
    end

    local result = {}
    local seen = {}
    for index = 1, count do
        local class = validateWeaponClass(value[index])
        if not class or seen[class] then
            return nil
        end
        seen[class] = true
        result[#result + 1] = class
    end
    table.sort(result)
    return result
end

local persistedAllowedWeapons = normalizeWeaponList(TS.Config.LuaAllowedWeapons) or {}
local invalidLuaWeaponListLogged = false

local function applyAllowedWeapons()
    local source = persistedAllowedWeapons
    if TS.Config.AllowedWeaponsLuaOverride == true then
        local normalized = normalizeWeaponList(TS.Config.LuaAllowedWeapons)
        if not normalized then
            if not invalidLuaWeaponListLogged then
                invalidLuaWeaponListLogged = true
                TS.Logging.Log(0, "Invalid Lua allowed_weapons list; weapon actions are blocked until the config is fixed")
            end
            normalized = {}
        end
        source = normalized
    end
    TS.Config.allowed_weapons = table.Copy(source)
end

function TS.Config.GetAllowedWeapons()
    return table.Copy(TS.Config.allowed_weapons or {})
end

function TS.Config.GetAllowedWeaponsSource()
    return TS.Config.AllowedWeaponsLuaOverride == true and "lua" or "menu"
end

local persistedSuperAdmins = TS.Permissions.NormalizeSuperAdminList(TS.Permissions.GetSuperAdmins()) or {}

applyAllowedWeapons()

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

local function superAdminSettings()
    local online = {}
    for _, target in ipairs(player.GetHumans()) do
        online[target:SteamID64()] = target
    end

    local settings = {}
    for _, steamID64 in ipairs(persistedSuperAdmins) do
        local target = online[steamID64]
        settings[#settings + 1] = {
            steamid64 = steamID64,
            online = IsValid(target),
            name = IsValid(target) and TS.Utils.ClampString(string.gsub(target:Nick(), "%c", " "), 128) or "",
        }
    end
    return settings
end

local function sameStringList(left, right)
    if #left ~= #right then
        return false
    end
    for index = 1, #left do
        if left[index] ~= right[index] then
            return false
        end
    end
    return true
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
        allowed_weapons = table.Copy(persistedAllowedWeapons),
        server = serverSettings(),
        superadmins = table.Copy(persistedSuperAdmins),
        integrations = integrationSettings(),
        permissions = permissionSettings(),
    }, true)
    if not json then
        return false
    end

    return TS.Utils.WriteDataFile(SETTINGS_FILE, json)
end

local broadcastRuntimeSettings

function TS.Config.Load()
    TS.Storage.SettingsLoaded = false
    local savedServer = {}
    local savedIntegrations = {}
    local savedPermissions = {}
    local savedAllowedWeapons
    local savedSuperAdmins

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
            and (decoded.superadmins == nil or istable(decoded.superadmins))
            and (decoded.allowed_weapons == nil or istable(decoded.allowed_weapons))
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
        if valid and decoded.allowed_weapons ~= nil then
            local normalized = normalizeWeaponList(decoded.allowed_weapons)
            if not normalized then
                valid = false
            else
                savedAllowedWeapons = normalized
            end
        end
        if valid and decoded.superadmins ~= nil then
            local normalized = TS.Permissions.NormalizeSuperAdminList(decoded.superadmins)
            if not normalized then
                valid = false
            else
                savedSuperAdmins = normalized
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
    if savedAllowedWeapons ~= nil then
        persistedAllowedWeapons = savedAllowedWeapons
    end
    applyAllowedWeapons()

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

    local migrateSuperAdmins = savedSuperAdmins == nil and #persistedSuperAdmins > 0
    if savedSuperAdmins ~= nil then
        persistedSuperAdmins = savedSuperAdmins
    end
    TS.Permissions.ApplySuperAdmins(persistedSuperAdmins)

    TS.Storage.SettingsLoaded = true
    TS.Integrations.RefreshAll()
    if TS.Config.logging ~= -1 and (not TS.Logging.IsAvailable or not TS.Logging.IsAvailable()) then
        TS.Config.logging = -1
    end
    if broadcastRuntimeSettings then
        broadcastRuntimeSettings()
    end
    if migrateSuperAdmins and not TS.Config.Save() then
        TS.Logging.Log(0, "Could not migrate individual superadmins to " .. SETTINGS_FILE)
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

function TS.Config.SetAllowedWeapon(class, allowed, actor)
    if TS.Config.AllowedWeaponsLuaOverride == true then
        return false, "weapon_lua_override"
    end

    class = validateWeaponClass(class)
    if not class or not isbool(allowed) then
        return false, "invalid_weapon_class"
    end

    local found
    for index, candidate in ipairs(persistedAllowedWeapons) do
        if candidate == class then
            found = index
            break
        end
    end

    if allowed and found then
        return true
    end
    if not allowed and not found then
        return true
    end
    if allowed and #persistedAllowedWeapons >= MAX_ALLOWED_WEAPONS then
        return false, "weapon_limit_reached"
    end

    local previous = table.Copy(persistedAllowedWeapons)
    if allowed then
        persistedAllowedWeapons[#persistedAllowedWeapons + 1] = class
        table.sort(persistedAllowedWeapons)
    else
        table.remove(persistedAllowedWeapons, found)
    end
    applyAllowedWeapons()

    if not TS.Config.Save() then
        persistedAllowedWeapons = previous
        applyAllowedWeapons()
        return false, "save_failed"
    end

    hook.Run("Talksmith.AllowedWeaponChanged", class, allowed, actor)
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

local function emitSuperAdminChanges(previous, current, actor)
    local old = {}
    local new = {}
    for _, steamID64 in ipairs(previous) do
        old[steamID64] = true
    end
    for _, steamID64 in ipairs(current) do
        new[steamID64] = true
    end

    for _, steamID64 in ipairs(previous) do
        if not new[steamID64] then
            hook.Run("Talksmith.SuperAdminChanged", steamID64, false, actor)
        end
    end
    for _, steamID64 in ipairs(current) do
        if not old[steamID64] then
            hook.Run("Talksmith.SuperAdminChanged", steamID64, true, actor)
        end
    end
end

function TS.Config.GetSuperAdmins()
    return table.Copy(persistedSuperAdmins)
end

function TS.Config.ReplaceSuperAdmins(values, actor)
    local normalized = TS.Permissions.NormalizeSuperAdminList(values)
    if not normalized then
        return false, "invalid_superadmin"
    end
    if sameStringList(persistedSuperAdmins, normalized) then
        TS.Permissions.ApplySuperAdmins(normalized)
        return true
    end

    local previous = table.Copy(persistedSuperAdmins)
    persistedSuperAdmins = normalized
    if TS.Storage.SettingsLoaded ~= true then
        TS.Permissions.ApplySuperAdmins(normalized)
        return true
    end
    if not TS.Config.Save() then
        persistedSuperAdmins = previous
        return false, "save_failed"
    end

    TS.Permissions.ApplySuperAdmins(normalized)
    emitSuperAdminChanges(previous, normalized, actor)
    if not IsValid(actor) and TS.Network.BroadcastSettings then
        TS.Network.BroadcastSettings(nil, true, "")
    end
    return true
end

function TS.Config.SetSuperAdmin(value, allowed, actor)
    local steamID64 = TS.Permissions.NormalizeSuperAdminSteamID(value)
    if not steamID64 or not isbool(allowed) then
        return false, "invalid_superadmin"
    end

    local found
    for index, candidate in ipairs(persistedSuperAdmins) do
        if candidate == steamID64 then
            found = index
            break
        end
    end
    if allowed and found or not allowed and not found then
        return true
    end
    if allowed and #persistedSuperAdmins >= MAX_SUPERADMINS then
        return false, "superadmin_limit_reached"
    end

    local updated = table.Copy(persistedSuperAdmins)
    if allowed then
        updated[#updated + 1] = steamID64
        table.sort(updated)
    else
        table.remove(updated, found)
    end
    return TS.Config.ReplaceSuperAdmins(updated, actor)
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
    local canManagePermissions = TS.Permissions.Has(player, "talksmith.settings.manage")
    local data = {
        api_version = TS.API.IntegrationVersion,
        can_manage_settings = TS.Permissions.Has(player, "talksmith.settings.manage"),
        can_manage_integrations = TS.Permissions.Has(player, "talksmith.integrations.manage"),
        can_manage_permissions = canManagePermissions,
        permissions_available = backendID ~= nil,
        permission_backend = backendID or "",
        permission_backend_name = backendName or "",
        permission_groups = backendID and TS.Permissions.GetGroupCatalog() or {},
        permissions = backendID and TS.Permissions.GetSettings() or {},
        logging_available = TS.Logging.IsAvailable and TS.Logging.IsAvailable() or false,
        allowed_weapons = TS.Config.GetAllowedWeapons(),
        allowed_weapons_source = TS.Config.GetAllowedWeaponsSource(),
        allowed_weapons_limit = MAX_ALLOWED_WEAPONS,
        superadmins = canManagePermissions and superAdminSettings() or {},
        superadmins_limit = MAX_SUPERADMINS,
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

net.Receive("ts_weapon_allowlist_update", function(len, player)
    if len > 800
        or not TS.Network.Allow(player, "weapon_allowlist_update", 0.2)
        or not TS.Permissions.CanUseEditor(player, "talksmith.settings.manage")
    then
        return
    end

    local allowed = net.ReadBool()
    local class = net.ReadString() or ""
    local ok, code = TS.Config.SetAllowedWeapon(class, allowed, player)
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

net.Receive("ts_superadmin_update", function(len, player)
    if len > 400
        or not TS.Network.Allow(player, "superadmin_update", 0.25)
        or not TS.Permissions.CanUseEditor(player, "talksmith.settings.manage")
        or not TS.Permissions.HasAdminBackend()
    then
        return
    end

    local allowed = net.ReadBool()
    local steamID = net.ReadString() or ""
    if #steamID <= 0 or #steamID > 32 then
        broadcastSettings(player, false, "invalid_superadmin")
        return
    end

    local ok, code = TS.Config.SetSuperAdmin(steamID, allowed, player)
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
