local TS = Talksmith
local CATEGORY_ID = 212937346
local MAX_MESSAGE_LENGTH = 2048

local function apiAvailable()
    return istable(ULogs)
        and istable(ULogs.LogTypes)
        and isfunction(ULogs.AddLogType)
        and (CLIENT or isfunction(ULogs.AddLog))
end

local function registerCategory()
    if not apiAvailable() then
        return false
    end

    local existing = ULogs.LogTypes[CATEGORY_ID]
    if existing then
        return existing.TalksmithCategory == true
    end

    local ok = pcall(ULogs.AddLogType, CATEGORY_ID, 0, "Talksmith", function()
        return {}
    end)
    if not ok then
        return false
    end

    existing = ULogs.LogTypes[CATEGORY_ID]
    if not istable(existing) then
        return false
    end

    existing.TalksmithCategory = true
    return true
end

TS.Logging.EnsureUltimateLogs = registerCategory

function TS.Logging.IsAvailable()
    return registerCategory()
end

if SERVER then
    local function cleanText(value, maximum)
        value = string.gsub(tostring(value or ""), "%c", " ")
        return TS.Utils.ClampString(value, maximum)
    end

    local function safePlayerInformation(player)
        if not IsValid(player) or not player:IsPlayer() then
            return {}
        end

        local name = cleanText(player:Nick(), 128)
        local steamID = cleanText(player:SteamID(), 32)
        return {
            { "Name : " .. name, name },
            { "SteamID : " .. steamID, steamID },
        }
    end

    function TS.Logging.WriteUltimateLog(level, message, context)
        if not registerCategory() or not isfunction(ULogs.AddLog) then
            return false
        end

        local label = level == 0 and "Error" or "Event"
        local information = {
            { "Source : Talksmith", "Talksmith" },
            { "Level : " .. label, string.lower(label) },
        }
        if istable(context) and IsValid(context.player) then
            table.Add(information, safePlayerInformation(context.player))
        end

        local text = cleanText(message, MAX_MESSAGE_LENGTH)
        local ok = pcall(ULogs.AddLog, CATEGORY_ID, "[Talksmith][" .. label .. "] " .. text, information)
        return ok
    end
end

local function refresh()
    registerCategory()
end

hook.Add("InitPostEntity", "Talksmith.UltimateLogsCategory", refresh)
hook.Add("OnReloaded", "Talksmith.UltimateLogsCategory", function()
    timer.Simple(0, refresh)
end)

if SERVER then
    hook.Add("Talksmith.DialogueSaved", "Talksmith.UltimateLogsDialogueSaved", function(id, revision, author)
        TS.Logging.Log(
            1,
            "Dialogue '" .. tostring(id) .. "' saved as revision " .. tostring(revision)
                .. " by " .. tostring(author or "server")
        )
    end)

    hook.Add("Talksmith.DialogueDeleted", "Talksmith.UltimateLogsDialogueDeleted", function(id)
        TS.Logging.Log(1, "Dialogue '" .. tostring(id) .. "' deleted")
    end)

    hook.Add("Talksmith.ConfigChanged", "Talksmith.UltimateLogsConfigChanged", function(key)
        TS.Logging.Log(1, "Server setting '" .. tostring(key) .. "' changed")
    end)

    hook.Add("Talksmith.IntegrationSettingChanged", "Talksmith.UltimateLogsIntegrationChanged", function(id, enabled)
        TS.Logging.Log(1, "Integration '" .. tostring(id) .. "' " .. (enabled and "enabled" or "disabled"))
    end)

    hook.Add("Talksmith.PermissionSettingChanged", "Talksmith.UltimateLogsPermissionChanged", function(right, group, player)
        TS.Logging.Log(
            1,
            "Privilege '" .. tostring(right) .. "' minimum group changed to '" .. tostring(group) .. "'",
            { player = player }
        )
    end)
end
