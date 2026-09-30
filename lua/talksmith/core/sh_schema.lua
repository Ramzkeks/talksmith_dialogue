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

function TS.Dialogues.DefaultNodeFields()
    return { sound = "", gesture = "", actions = {}, options = {} }
end

function TS.Dialogues.DefaultOptionFields()
    return { next_random = {}, gesture = "", conditions = {}, actions = {} }
end

local function fillMissing(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then target[key] = istable(value) and TS.Utils.Copy(value) or value end
    end
end

-- Additive fields belong in these defaults. Only absence gets a fallback:
-- false, zero, empty strings and malformed values must not be overwritten.
-- This never writes to disk or changes the caller's document/revision.
function TS.Dialogues.Normalize(document)
    if not istable(document) then return document end
    local doc = TS.Utils.Copy(document)
    if doc.schema ~= TS.Dialogues.Schema then return doc end
    if doc.settings == nil then doc.settings = {} end
    if istable(doc.settings) then fillMissing(doc.settings, TS.Dialogues.DefaultSettings()) end
    if istable(doc.meta) and doc.meta.revision == nil then doc.meta.revision = 0 end
    if istable(doc.nodes) then
        local nodeDefaults, optionDefaults = TS.Dialogues.DefaultNodeFields(), TS.Dialogues.DefaultOptionFields()
        for _, node in pairs(doc.nodes) do
            if istable(node) then
                fillMissing(node, nodeDefaults)
                if istable(node.options) then
                    for _, option in ipairs(node.options) do
                        if istable(option) then fillMissing(option, optionDefaults) end
                    end
                end
            end
        end
    end
    return doc
end

function TS.Dialogues.New(id, author)
    local now = os.time()

    local doc = {
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
    return TS.Dialogues.Normalize(doc)
end
