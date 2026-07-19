local TS = Talksmith
TS.Dialogues.Schema = 3

function TS.Dialogues.DefaultSettings()
    return {
        actor_name = "Собеседник",
        actor_subtitle = "",
        actor_model = "models/Humans/Group01/male_02.mdl",
        interact_distance = 160,
        actor_scale = 1,
        actor_skin = 0,
        actor_bodygroups = {},
        name_offset = 82,
        idle_sequence = "",
        idle_sequences = {},
        theme = "default",
        use_limit = false,
        start_random = {},
    }
end

function TS.Dialogues.New(id, author)
    local now = os.time()

    return {
        schema = TS.Dialogues.Schema,
        id = id,
        meta = {
            title = id,
            author = author or "",
            created = now,
            modified = now,
            revision = 0,
            open_dialogue_revisions = {},
            open_dialogue_fingerprints = {},
        },
        settings = TS.Dialogues.DefaultSettings(),
        start = "greeting",
        nodes = {
            greeting = {
                editor = {
                    x = 180,
                    y = 160,
                },
                text = "Здравствуйте.",
                sound = "",
                gesture = "",
                actions = {},
                options = {
                    {
                        text = "До встречи.",
                        next = nil,
                        next_random = {},
                        gesture = "",
                        conditions = {},
                        actions = {},
                    },
                },
            },
        },
    }
end
