local TS = Talksmith

TS.Config = TS.Config or {}

local defaults = {
    editor_enabled = true,
    interact_distance = 160,
    max_nodes = 256,
    max_options = 6,
    max_document_bytes = 524288,
    max_actor_layout_bytes = 1048576,
    max_flag_file_bytes = 131072,
    max_flags_per_player = 256,
    max_action_entries = 16,
    max_condition_entries = 32,
    max_action_cost = 64,
    max_random_targets = 64,
    max_variable_resolutions = 64,
    max_validation_issues = 256,
    choice_cooldown = 0.35,
    open_cooldown = 1,
    session_idle_timeout = 90,
    session_max_duration = 600,
    require_line_of_sight = true,
    max_actors = 128,
    backups = 5,
    show_name = true,
    show_description = true,
    show_interaction = true,
    language = "en",
    logging = -1,
    integrations = {},
    permission_groups = {
        ["talksmith.editor.open"] = "superadmin",
        ["talksmith.dialogues.create"] = "superadmin",
        ["talksmith.dialogues.edit"] = "superadmin",
        ["talksmith.dialogues.delete"] = "superadmin",
        ["talksmith.dialogues.publish"] = "superadmin",
        ["talksmith.actors.manage"] = "superadmin",
        ["talksmith.settings.manage"] = "superadmin",
        ["talksmith.integrations.manage"] = "superadmin",
        ["talksmith.diagnostics.view"] = "superadmin",
        ["talksmith.actions.dangerous"] = "superadmin",
        ["talksmith.actions.economy"] = "superadmin",
        ["talksmith.actions.inventory"] = "superadmin",
        ["talksmith.actions.progression"] = "superadmin",
        ["talksmith.actions.jobs"] = "superadmin",
        ["talksmith.actions.events"] = "superadmin",
        ["talksmith.wire.manage"] = "superadmin",
    },
    autosave_actors = true,
    number_hotkeys = true,
    dialogue_speed = 1,
    dialogue_type_interval = 0.05,
    dialogue_post_delay = 0.2,
    dialogue_camera_settle = 0.2,
    spawns = {},
    allowed_models = {
        "*",
    },
    model_suggestions = {
        "models/Humans/Group01/male_02.mdl",
        "models/Humans/Group01/female_02.mdl",
        "models/Humans/Group03/male_07.mdl",
        "models/Humans/Group03/female_06.mdl",
        "models/breen.mdl",
        "models/alyx.mdl",
        "models/barney.mdl",
        "models/kleiner.mdl",
        "models/mossman.mdl",
        "models/eli.mdl",
        "models/gman_high.mdl",
        "models/police.mdl",
        "models/combine_soldier.mdl",
        "models/combine_super_soldier.mdl",
        "models/zombie/classic.mdl",
    },
    allowed_weapons = {
        "weapon_crowbar",
        "weapon_pistol",
    },
    allowed_teams = {},
    allowed_darkrp_jobs = {},
    allowed_inventory_entities = {
        common = {
            "item_healthkit",
            "item_healthvial",
            "item_battery",
            "item_ammo_357",
            "item_ammo_357_large",
            "item_ammo_ar2",
            "item_ammo_ar2_large",
            "item_ammo_ar2_altfire",
            "item_ammo_crossbow",
            "item_ammo_pistol",
            "item_ammo_pistol_large",
            "item_rpg_round",
            "item_box_buckshot",
            "item_ammo_smg1",
            "item_ammo_smg1_large",
            "item_ammo_smg1_grenade",
        },
        barney = {},
        finventory = {},
        gws = {},
    },
    darkrp_max_money_action = 1000000,
    allowed_sounds = {
        "buttons/button14.wav",
    },
    remote_audio_enabled = true,
    max_remote_audio_url_length = 2048,
    allowed_remote_audio_hosts = {
        "*",
    },
    allowed_themes = {
        "default",
        "retro",
        "panorama",
        "openframe",
    },
    ui = {
        accent = Color(213, 151, 54),
    },
}

local function hasSameType(value, default)
    return type(value) == type(default)
end

for key, default in pairs(defaults) do
    if not hasSameType(TS.Config[key], default) then
        TS.Config[key] = default
    end
end

TS.Config.Defaults = defaults

function TS.Config.Get(key, fallback)
    local value = TS.Config[key]
    return value == nil and fallback or value
end
