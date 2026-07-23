local TS = Talksmith

local SETTINGS_FILE = "talksmith/editor_settings.json"
local SAVE_TIMER = "talksmith_editor_settings_save"
local MAX_SETTINGS_BYTES = 16384

local languageDefault = TS.Config.language == "en" and "en" or "ru"
local schema = {
    grid_size = { kind = "number", default = 16, min = 8, max = 64, integer = true },
    snap_to_grid = { kind = "boolean", default = true },
    confirm_delete = { kind = "boolean", default = true },
    help_seen = { kind = "boolean", default = false },
    language = { kind = "enum", default = languageDefault, values = { ru = true, en = true } },
}

local function validate(key, value)
    local rule = schema[key]
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
        if not isnumber(value) or value ~= value or value == math.huge or value == -math.huge then
            return nil
        end
        value = math.Clamp(value, rule.min, rule.max)
        if rule.integer then
            value = math.Round(value)
        end
        return value
    end

    if rule.kind == "enum" then
        return isstring(value) and rule.values[value] and value or nil
    end

    return nil
end

function TS.Editor.LoadSettings()
    local saved = {}
    if file.Exists(SETTINGS_FILE, "DATA") then
        local raw = file.Read(SETTINGS_FILE, "DATA")
        local withinLimit = isstring(raw) and #raw <= MAX_SETTINGS_BYTES
        local parsed, decoded = false, nil
        if withinLimit then
            parsed, decoded = pcall(util.JSONToTable, raw, false, true)
        end
        local valid = withinLimit and parsed and istable(decoded)
        if valid then
            for key, value in pairs(decoded) do
                if not schema[key] or validate(key, value) == nil then
                    valid = false
                    break
                end
            end
        end
        if valid then
            saved = decoded
            TS.Editor.SettingsWritable = true
        else
            TS.Editor.SettingsWritable = false
            TS.Logging.Log(0, "Rejected " .. SETTINGS_FILE .. ": invalid editor settings JSON")
        end
    else
        TS.Editor.SettingsWritable = true
    end

    TS.Editor.Settings = {}
    for key, rule in pairs(schema) do
        TS.Editor.Settings[key] = validate(key, saved[key])
        if TS.Editor.Settings[key] == nil then
            TS.Editor.Settings[key] = rule.default
        end
    end

    TS.Config.language = TS.Editor.Settings.language
    return TS.Editor.Settings
end

function TS.Editor.SaveSettings()
    if TS.Editor.SettingsWritable == false then
        return false
    end

    file.CreateDir("talksmith")
    local json = util.TableToJSON(TS.Editor.Settings or {}, true)
    if not json or #json > MAX_SETTINGS_BYTES then
        return false
    end
    return TS.Utils.WriteDataFile(SETTINGS_FILE, json)
end

function TS.Editor.GetSetting(key)
    local rule = schema[key]
    if not rule then
        return nil
    end
    if not TS.Editor.Settings then
        TS.Editor.LoadSettings()
    end
    local value = validate(key, TS.Editor.Settings[key])
    return value == nil and rule.default or value
end

function TS.Editor.SetSetting(key, value)
    value = validate(key, value)
    if value == nil then
        return false
    end

    TS.Editor.Settings = TS.Editor.Settings or {}
    if TS.Editor.Settings[key] == value then
        return true
    end

    TS.Editor.Settings[key] = value
    if key == "language" then
        TS.Config.language = value
    end

    timer.Create(SAVE_TIMER, 0.2, 1, function()
        if not TS.Editor.SaveSettings() then
            TS.Logging.Log(0, "Could not save Talksmith editor settings")
        end
    end)
    hook.Run("Talksmith.EditorSettingChanged", key, value)
    return true
end

TS.Editor.SettingSchema = schema
TS.Editor.LoadSettings()

hook.Add("ShutDown", "Talksmith.SaveEditorSettings", function()
    if timer.Exists(SAVE_TIMER) then
        if not TS.Editor.SaveSettings() then
            TS.Logging.Log(0, "Could not save Talksmith editor settings during shutdown")
        end
    end
end)
