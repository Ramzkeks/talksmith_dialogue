local TS = Talksmith
local issueStates = setmetatable({}, { __mode = "k" })

local function issue(out, severity, path, text)
    local state = issueStates[out]
    if state and severity == "error" then
        state.hasError = true
    end
    local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_validation_issues) or 256), 32, 1024)
    if #out >= maximum then
        if state then state.truncated = true end
        return
    end
    out[#out + 1] = { severity = severity, path = path, message = text }
end

local function finiteNumber(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

local function validEditorColor(color)
    if color == nil then
        return true
    end
    if not istable(color) then
        return false
    end
    for _, channel in ipairs({ "r", "g", "b" }) do
        local value = color[channel]
        if not finiteNumber(value) or value < 0 or value > 255 or value ~= math.floor(value) then
            return false
        end
    end
    return true
end

local function checkRefs(out, path, list, lookup, kind)
    if list ~= nil and not istable(list) then
        issue(out, "error", path, "Invalid " .. kind .. " list")
        return
    end
    local maximum = kind == "action"
        and math.Clamp(math.floor(tonumber(TS.Config.max_action_entries) or 16), 1, 64)
        or math.Clamp(math.floor(tonumber(TS.Config.max_condition_entries) or 32), 1, 64)
    if istable(list) and #list > maximum then
        issue(out, "error", path, "Too many " .. kind .. " entries")
    end
    local actionCost = 0
    for index = 1, math.min(istable(list) and #list or 0, maximum) do
        local entry = list[index]
        if not istable(entry) or not isstring(entry.id) then
            issue(out, "error", path, "Invalid " .. kind .. " entry")
        else
            local definition = lookup(entry.id)
            if not definition then
                issue(out, "error", path, "Unknown " .. kind .. ": " .. tostring(entry.id))
            else
                local good, why = TS.Validation.ValidateParams(definition.params, entry.params)
                if not good then
                    issue(out, "error", path, definition.id .. ": " .. why)
                elseif definition.provider_kind and TS.Providers.CountAvailable then
                    local params = istable(entry.params) and entry.params or {}
                    local provider = params.provider
                    if (provider == nil or provider == "" or provider == "auto")
                        and TS.Providers.CountAvailable(definition.provider_kind, definition.provider_method) > 1
                    then
                        issue(out, "error", path, definition.id .. ": provider must be selected")
                    end
                end
                if kind == "action" then
                    if definition.integration == "vj" and definition.vj_scene_action and #list ~= 1 then
                        issue(out, "error", path, definition.id .. ": must be the only action in this list")
                    end
                    local cost = math.max(tonumber(definition.action_cost) or 1, 1)
                    if isstring(definition.cost_param) then
                        local value = istable(entry.params) and tonumber(entry.params[definition.cost_param]) or nil
                        if value then
                            cost = math.max(
                                cost,
                                math.max(value, 0) * math.max(tonumber(definition.cost_multiplier) or 1, 0)
                            )
                        end
                    end
                    actionCost = actionCost + cost
                    if actionCost > math.Clamp(tonumber(TS.Config.max_action_cost) or 64, 1, 1024) then
                        issue(out, "error", path, "Action cost exceeds the server budget")
                        break
                    end
                end
            end
        end
    end
end

local function tooManyVariables(value)
    if not isstring(value) then
        return false
    end
    local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_variable_resolutions) or 64), 1, 256)
    local count = 0
    for _ in value:gmatch("{[a-zA-Z0-9_%.%-]+:?[^}]*}") do
        count = count + 1
        if count > maximum then
            return true
        end
    end
    return false
end

function TS.Validation.ValidateDialogue(doc)
    local out = {}
    issueStates[out] = { hasError = false, truncated = false }
    if not istable(doc) then
        return false, { { severity = "error", path = "/", message = "Document is not an object" } }
    end
    if doc.schema ~= TS.Dialogues.Schema then
        issue(out, "error", "schema", "Unsupported schema")
    end
    if TS.Utils.SafeID(doc.id) ~= doc.id then
        issue(out, "error", "id", "Invalid ID")
    end
    if not istable(doc.meta) or not isstring(doc.meta.title) or TS.Utils._UTF8Length(doc.meta.title) > 128 then
        issue(out, "error", "meta", "Invalid metadata")
    else
        local meta = doc.meta
        if meta.author ~= nil and (not isstring(meta.author) or TS.Utils._UTF8Length(meta.author) > 64) then
            issue(out, "error", "meta.author", "Invalid author")
        end
        for _, field in ipairs({ "created", "modified", "revision" }) do
            local value = meta[field]
            if
                value ~= nil
                and (
                    not finiteNumber(value)
                    or value < 0
                    or value ~= math.floor(value)
                    or (field == "revision" and value > 4294967295)
                    or (field ~= "revision" and value > 32503680000)
                )
            then
                issue(out, "error", "meta." .. field, "Invalid " .. field)
            end
        end
        if meta.open_dialogue_revisions ~= nil then
            if not istable(meta.open_dialogue_revisions) then
                issue(out, "error", "meta.open_dialogue_revisions", "Invalid dialogue dependency snapshot")
            else
                local dependencyCount = 0
                for dialogueID, revision in pairs(meta.open_dialogue_revisions) do
                    dependencyCount = dependencyCount + 1
                    if dependencyCount > 4096 then
                        issue(out, "error", "meta.open_dialogue_revisions", "Too many dialogue dependencies")
                        break
                    end
                    if TS.Utils.SafeID(dialogueID) ~= dialogueID
                        or not finiteNumber(revision)
                        or revision < 0
                        or revision ~= math.floor(revision)
                        or revision > 4294967295
                    then
                        issue(
                            out,
                            "error",
                            "meta.open_dialogue_revisions." .. tostring(dialogueID),
                            "Invalid dialogue dependency revision"
                        )
                    end
                end
            end
        end
        if meta.open_dialogue_fingerprints ~= nil then
            if not istable(meta.open_dialogue_fingerprints) then
                issue(out, "error", "meta.open_dialogue_fingerprints", "Invalid dialogue dependency fingerprints")
            else
                local fingerprintCount = 0
                for dialogueID, fingerprint in pairs(meta.open_dialogue_fingerprints) do
                    fingerprintCount = fingerprintCount + 1
                    if fingerprintCount > 4096 then
                        issue(out, "error", "meta.open_dialogue_fingerprints", "Too many dialogue fingerprints")
                        break
                    end
                    if TS.Utils.SafeID(dialogueID) ~= dialogueID
                        or not isstring(fingerprint)
                        or #fingerprint ~= 64
                        or not string.match(fingerprint, "^[0-9a-f]+$")
                    then
                        issue(
                            out,
                            "error",
                            "meta.open_dialogue_fingerprints." .. tostring(dialogueID),
                            "Invalid dialogue dependency fingerprint"
                        )
                    end
                end
            end
        end
        if istable(meta.open_dialogue_revisions) and istable(meta.open_dialogue_fingerprints) then
            for dialogueID in pairs(meta.open_dialogue_revisions) do
                if meta.open_dialogue_fingerprints[dialogueID] == nil then
                    issue(out, "error", "meta.open_dialogue_fingerprints", "Missing dialogue dependency fingerprint")
                    break
                end
            end
            for dialogueID in pairs(meta.open_dialogue_fingerprints) do
                if meta.open_dialogue_revisions[dialogueID] == nil then
                    issue(out, "error", "meta.open_dialogue_revisions", "Missing dialogue dependency revision")
                    break
                end
            end
        end
    end

    if not istable(doc.settings) or not isstring(doc.settings.actor_name) or TS.Utils._UTF8Length(doc.settings.actor_name) > 128 then
        issue(out, "error", "settings", "Invalid Actor settings")
    else
        local settings = doc.settings
        for _, field in ipairs({
            "actor_subtitle",
            "actor_model",
            "interact_distance",
            "actor_scale",
            "actor_skin",
            "actor_bodygroups",
            "name_offset",
            "idle_sequence",
            "idle_sequences",
            "theme",
            "use_limit",
            "start_random",
        }) do
            if settings[field] == nil then
                issue(out, "error", "settings." .. field, "Missing " .. field)
            end
        end
        local function str(field, max)
            if settings[field] ~= nil and (not isstring(settings[field]) or #settings[field] > max) then
                issue(out, "error", "settings." .. field, "Invalid " .. field)
            end
        end
        local function num(field, min, max, integer)
            local value = settings[field]
            if value == nil then
                return
            end
            if not finiteNumber(value) or value < min or value > max or (integer and value ~= math.floor(value)) then
                issue(out, "error", "settings." .. field, "Invalid " .. field)
            end
        end

        if settings.actor_subtitle ~= nil
            and (not isstring(settings.actor_subtitle) or TS.Utils._UTF8Length(settings.actor_subtitle) > 128)
        then
            issue(out, "error", "settings.actor_subtitle", "Invalid actor_subtitle")
        end
        str("actor_model", 256)
        str("idle_sequence", 64)
        if isstring(settings.actor_model) and not TS.Utils.IsModelAllowed(settings.actor_model) then
            issue(out, "error", "settings.actor_model", "Model is not allowed")
        end
        num("actor_scale", 0.25, 4, false)
        num("actor_skin", 0, 255, true)
        num("name_offset", 1, 256, false)
        num("interact_distance", 64, 512, false)

        if settings.use_limit ~= nil and not isbool(settings.use_limit) then
            issue(out, "error", "settings.use_limit", "Invalid use_limit")
        end
        if settings.actor_bodygroups ~= nil and not istable(settings.actor_bodygroups) then
            issue(out, "error", "settings.actor_bodygroups", "Invalid bodygroups")
        else
            local bodygroupCount = table.Count(settings.actor_bodygroups or {})
            if bodygroupCount > 64 then
                issue(out, "error", "settings.actor_bodygroups", "Too many bodygroups")
            end
            for id, value in pairs(bodygroupCount <= 64 and settings.actor_bodygroups or {}) do
                local numericID = tonumber(id)
                if
                    not numericID
                    or numericID < 0
                    or numericID > 255
                    or numericID ~= math.floor(numericID)
                    or not finiteNumber(value)
                    or value < 0
                    or value > 63
                    or value ~= math.floor(value)
                then
                    issue(out, "error", "settings.actor_bodygroups", "Invalid bodygroup value")
                end
            end
        end
        if settings.idle_sequences ~= nil and not istable(settings.idle_sequences) then
            issue(out, "error", "settings.idle_sequences", "Invalid idle_sequences")
        else
            if #(settings.idle_sequences or {}) > 64 then
                issue(out, "error", "settings.idle_sequences", "Too many idle sequences")
            end
            for index = 1, math.min(#(settings.idle_sequences or {}), 64) do
                local sequence = settings.idle_sequences[index]
                if not isstring(sequence) or #sequence > 64 then
                    issue(out, "error", "settings.idle_sequences", "Invalid idle sequence")
                end
            end
        end
        if settings.start_random ~= nil and not istable(settings.start_random) then
            issue(out, "error", "settings.start_random", "Invalid start_random")
        else
            local randomStarts = settings.start_random or {}
            local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_random_targets) or 64), 1, 256)
            if #randomStarts > maximum then
                issue(out, "error", "settings.start_random", "Too many random start nodes")
            end
            for index = 1, math.min(#randomStarts, maximum) do
                local target = randomStarts[index]
                if not isstring(target) or not istable(doc.nodes) or not istable(doc.nodes[target]) then
                    issue(out, "error", "settings.start_random", "Start node missing: " .. tostring(target))
                end
            end
        end
        if
            settings.theme ~= nil
            and (not isstring(settings.theme) or not TS.Utils.InList(TS.Config.allowed_themes, settings.theme))
        then
            issue(out, "error", "settings.theme", "Unknown theme")
        end
    end

    if not istable(doc.nodes) then
        issue(out, "error", "nodes", "Nodes missing")
        return false, out
    end
    if table.Count(doc.nodes) > TS.Config.max_nodes then
        issue(out, "error", "nodes", "Too many nodes")
        return false, out
    end
    if not TS.Utils.SafeID(doc.start) or not istable(doc.nodes[doc.start]) then
        issue(out, "error", "start", "Start node missing")
    end

    for id, node in pairs(doc.nodes) do
        local nodeID = tostring(id)
        local base = "nodes." .. nodeID
        if TS.Utils.SafeID(id) ~= id then
            issue(out, "error", base, "Invalid node ID")
        end
        if not istable(node) then
            issue(out, "error", base, "Node is not an object")
        else
            for _, field in ipairs({ "sound", "gesture", "actions", "options" }) do
                if node[field] == nil then
                    issue(out, "error", base .. "." .. field, "Missing " .. field)
                end
            end
            if not isstring(node.text) or TS.Utils._UTF8Length(node.text) > 4096 then
                issue(out, "error", base .. ".text", "Invalid text")
            elseif tooManyVariables(node.text) then
                issue(out, "error", base .. ".text", "Too many variable references")
            end
            if node.sound ~= nil and (not isstring(node.sound) or not TS.Utils.IsSoundAllowed(node.sound)) then
                issue(out, "error", base .. ".sound", "Sound is not allowed: " .. tostring(node.sound))
            end
            if node.gesture ~= nil and (not isstring(node.gesture) or #node.gesture > 64) then
                issue(out, "error", base .. ".gesture", "Invalid gesture")
            end
            if node.editor ~= nil then
                if not istable(node.editor) then
                    issue(out, "error", base .. ".editor", "Invalid editor metadata")
                else
                    local editor = node.editor
                    if editor.x ~= nil and (not finiteNumber(editor.x) or math.abs(editor.x) > 1000000) then
                        issue(out, "error", base .. ".editor.x", "Invalid editor position")
                    end
                    if editor.y ~= nil and (not finiteNumber(editor.y) or math.abs(editor.y) > 1000000) then
                        issue(out, "error", base .. ".editor.y", "Invalid editor position")
                    end
                    if editor.note ~= nil and (not isstring(editor.note) or TS.Utils._UTF8Length(editor.note) > 512) then
                        issue(out, "error", base .. ".editor.note", "Invalid editor note")
                    end
                    if not validEditorColor(editor.color) then
                        issue(out, "error", base .. ".editor.color", "Invalid editor color")
                    end
                end
            end
            checkRefs(out, base .. ".actions", node.actions, TS.Actions.Get, "action")

            local options = istable(node.options) and node.options or {}
            if not istable(node.options) or #options < 1 or #options > TS.Config.max_options then
                issue(out, "error", base .. ".options", "Options must contain 1–" .. TS.Config.max_options .. " items")
            end
            for index = 1, math.min(#options, TS.Config.max_options) do
                local option = options[index]
                local optionPath = base .. ".options." .. index
                if not istable(option) then
                    issue(out, "error", optionPath, "Option is not an object")
                else
                    for _, field in ipairs({ "next_random", "gesture", "conditions", "actions" }) do
                        if option[field] == nil then
                            issue(out, "error", optionPath .. "." .. field, "Missing " .. field)
                        end
                    end
                    if not isstring(option.text) or #option.text < 1 or TS.Utils._UTF8Length(option.text) > 512 then
                        issue(out, "error", optionPath, "Invalid option text")
                    elseif tooManyVariables(option.text) then
                        issue(out, "error", optionPath, "Too many variable references")
                    end
                    local randomTargets = istable(option.next_random) and option.next_random or {}
                    if
                        #randomTargets == 0
                        and option.next ~= nil
                        and (not isstring(option.next) or not istable(doc.nodes[option.next]))
                    then
                        issue(out, "error", optionPath, "Target node missing: " .. tostring(option.next))
                    end
                    if option.gesture ~= nil and (not isstring(option.gesture) or #option.gesture > 64) then
                        issue(out, "error", optionPath .. ".gesture", "Invalid gesture")
                    end
                    if option.next_random ~= nil and not istable(option.next_random) then
                        issue(out, "error", optionPath .. ".next_random", "Invalid random targets")
                    else
                        local maximum = math.Clamp(
                            math.floor(tonumber(TS.Config.max_random_targets) or 64),
                            1,
                            256
                        )
                        if #randomTargets > maximum then
                            issue(out, "error", optionPath .. ".next_random", "Too many random targets")
                        end
                        for randomIndex = 1, math.min(#randomTargets, maximum) do
                            local target = randomTargets[randomIndex]
                            if not isstring(target) or not istable(doc.nodes[target]) then
                                issue(
                                    out,
                                    "error",
                                    optionPath .. ".next_random",
                                    "Target node missing: " .. tostring(target)
                                )
                            end
                        end
                    end
                    checkRefs(out, optionPath .. ".actions", option.actions, TS.Actions.Get, "action")
                    checkRefs(out, optionPath .. ".conditions", option.conditions, TS.Conditions.Get, "condition")
                end
            end
        end
    end

    local reachable, queue, head = {}, { doc.start }, 1
    if istable(doc.settings) and istable(doc.settings.start_random) then
        local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_random_targets) or 64), 1, 256)
        for index = 1, math.min(#doc.settings.start_random, maximum) do
            queue[#queue + 1] = doc.settings.start_random[index]
        end
    end
    while head <= #queue do
        local id = queue[head]
        head = head + 1
        local node = id and doc.nodes[id]
        if id and not reachable[id] and istable(node) then
            reachable[id] = true
            local options = istable(node.options) and node.options or {}
            for optionIndex = 1, math.min(#options, TS.Config.max_options) do
                local option = options[optionIndex]
                if istable(option) then
                    local randomTargets = istable(option.next_random) and option.next_random or {}
                    if #randomTargets == 0 and option.next then
                        queue[#queue + 1] = option.next
                    end
                    local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_random_targets) or 64), 1, 256)
                    for index = 1, math.min(#randomTargets, maximum) do
                        queue[#queue + 1] = randomTargets[index]
                    end
                end
            end
        end
    end
    for id, node in pairs(doc.nodes) do
        if istable(node) and not reachable[id] then
            issue(out, "warning", "nodes." .. tostring(id), "Unreachable node")
        end
    end

    local state = issueStates[out]
    if state and state.hasError then
        return false, out
    end
    return true, out
end
