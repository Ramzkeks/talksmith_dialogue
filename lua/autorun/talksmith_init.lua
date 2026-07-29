Talksmith = Talksmith or {}
local TS = Talksmith

TS.API = TS.API or {}
TS.API.Name = "Talksmith - Advanced NPC Dialogue Framework"
TS.API.ShortName = "Talksmith"
TS.API.StudioName = "Talksmith Studio"
TS.API.ActorName = "Talksmith Actor"
TS.API.Version = "2.0.0"
TS.API.IntegrationVersion = 1
TS.Actions = TS.Actions or {}
TS.Actions.Registry = TS.Actions.Registry or {}
TS.Actors = TS.Actors or {}
TS.Conditions = TS.Conditions or {}
TS.Conditions.Registry = TS.Conditions.Registry or {}
TS.Config = TS.Config or {}
TS.Dialogues = TS.Dialogues or {}
TS.Dialogues.Registry = TS.Dialogues.Registry or {}
TS.Dialogues.Schema = 3
TS.Editor = TS.Editor or {}
TS.Examples = TS.Examples or {}
TS.Integrations = TS.Integrations or {}
TS.Integrations.Registry = TS.Integrations.Registry or {}
TS.Integrations.Variables = TS.Integrations.Variables or {}
TS.Localization = TS.Localization or {}
TS.Logging = TS.Logging or {}
TS.Network = TS.Network or {}
TS.Permissions = TS.Permissions or {}
TS.Providers = TS.Providers or {}
TS.Providers.Registry = TS.Providers.Registry or {}
TS.Runtime = TS.Runtime or {}
TS.Runtime.Sessions = TS.Runtime.Sessions or setmetatable({}, { __mode = "k" })
TS.Runtime.Camera = TS.Runtime.Camera or {}
TS.Storage = TS.Storage or {}
TS.Utils = TS.Utils or {}
TS.Validation = TS.Validation or {}

local shared = {
    "core/sh_config.lua",
    "core/sh_util.lua",
    "core/sh_log.lua",
    "core/sh_registry.lua",
    "integrations/sh_integrations.lua",
    "integrations/sh_ultimate_logs.lua",
    "core/sh_schema.lua",
    "core/sh_validate.lua",
    "core/sh_i18n.lua",
    "core/sh_examples.lua",
    "integrations/sh_i18n.lua",
    "integrations/sh_reference_i18n.lua",
    "api/sh_api.lua",
}

local server = {
    "server/sv_permissions.lua",
    "server/sv_ratelimit.lua",
    "server/sv_flags.lua",
    "server/sv_actions.lua",
    "server/sv_conditions.lua",
    "integrations/sv_inventory.lua",
    "integrations/sv_pointshop.lua",
    "integrations/sv_gws.lua",
    "integrations/sv_finventory.lua",
    "integrations/sv_barney.lua",
    "integrations/sv_leveling.lua",
    "integrations/sv_multicharacter.lua",
    "integrations/sv_advanced_character_creator.lua",
    "integrations/sv_stormfox2.lua",
    "integrations/sv_ulib.lua",
    "integrations/sv_ulx.lua",
    "integrations/sv_sadmin.lua",
    "integrations/sv_wiremod.lua",
    "integrations/sv_runtime.lua",
    "server/sv_settings_net.lua",
    "server/sv_store.lua",
    "server/sv_action_journal.lua",
    "server/sv_sessions.lua",
    "server/sv_actor_persist.lua",
    "server/sv_actor_manager.lua",
    "server/sv_runtime_net.lua",
    "server/sv_examples.lua",
    "server/sv_editor_net.lua",
}

local client = {
    "client/runtime/cl_theme.lua",
    "client/runtime/cl_dialogue_ui.lua",
    "client/runtime/cl_runtime_net.lua",
    "client/editor/cl_theme.lua",
    "client/editor/cl_reference_picker.lua",
    "client/editor/cl_examples.lua",
    "client/editor/cl_help.lua",
    "client/editor/cl_settings.lua",
    "client/editor/cl_preferences.lua",
    "client/editor/cl_addon_settings.lua",
    "client/editor/cl_integration_settings.lua",
    "client/editor/cl_portability.lua",
    "client/editor/cl_history.lua",
    "client/editor/cl_node.lua",
    "client/editor/cl_canvas.lua",
    "client/editor/cl_inspector.lua",
    "client/editor/cl_dialogue_list.lua",
    "client/editor/cl_problems.lua",
    "client/editor/cl_preview.lua",
    "client/editor/cl_editor_net.lua",
    "client/editor/cl_editor.lua",
}

local fontResources = {
    "resource/fonts/manrope_regular.ttf",
    "resource/fonts/manrope_medium.ttf",
    "resource/fonts/manrope_semibold.ttf",
    "resource/fonts/manrope_bold.ttf",
}

local iconResources = {
    "arrow-clockwise",
    "arrow-counter-clockwise",
    "arrow-down",
    "arrow-right",
    "arrow-up",
    "arrows-clockwise",
    "caret-down",
    "caret-left",
    "caret-right",
    "check-circle",
    "check",
    "circle-fill",
    "clipboard-text",
    "copy",
    "crosshair-simple",
    "crosshair",
    "diamond-fill",
    "dots-three",
    "download-simple",
    "flag",
    "floppy-disk",
    "folder-open",
    "gear-six",
    "link-break",
    "magnifying-glass",
    "minus",
    "pencil-simple",
    "play",
    "plus",
    "question",
    "sliders-horizontal",
    "stop",
    "trash",
    "upload-simple",
    "user-focus",
    "user-minus",
    "user-plus",
    "warning",
    "x-circle",
    "x",
}

if SERVER then
    for _, path in ipairs(fontResources) do
        resource.AddFile(path)
    end
    for _, name in ipairs(iconResources) do
        resource.AddFile("materials/talksmith/ui/" .. name .. ".png")
    end
end

for _, path in ipairs(shared) do
    if SERVER then
        AddCSLuaFile("talksmith/" .. path)
    end

    include("talksmith/" .. path)
end

if SERVER then
    for _, path in ipairs(client) do
        AddCSLuaFile("talksmith/" .. path)
    end

    for _, path in ipairs(server) do
        include("talksmith/" .. path)
    end
else
    for _, path in ipairs(client) do
        include("talksmith/" .. path)
    end
end
