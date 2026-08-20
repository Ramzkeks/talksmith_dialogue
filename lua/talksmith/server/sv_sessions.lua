local TS = Talksmith

TS.Runtime.Sessions = TS.Runtime.Sessions or setmetatable({}, { __mode = "k" })
local tokenSequence = 0

function TS.Runtime.GetSession(player)
    return TS.Runtime.Sessions[player]
end

function TS.Runtime.IsActive(player)
    return TS.Runtime.Sessions[player] ~= nil
end

function TS.Runtime.GetActorSession(actor, exceptPlayer)
    for player, session in pairs(TS.Runtime.Sessions) do
        if player ~= exceptPlayer and session.actor == actor and IsValid(player) then
            return session, player
        end
    end
end

function TS.Actors.RefreshBusy(actor)
    if not IsValid(actor) or not TS.Actors.IsActor(actor) then
        return
    end
    local active = TS.Runtime.GetActorSession(actor)
    local current = TS.Dialogues.Get(TS.Actors.GetDialogue(actor))
    local occupied = active ~= nil and current ~= nil and current.settings.use_limit == true
    TS.Actors.SetBusy(actor, occupied)
end

function TS.Actors.RefreshAllBusy()
    local activeActors = {}
    for player, session in pairs(TS.Runtime.Sessions) do
        if IsValid(player) and session.actor ~= nil then
            activeActors[session.actor] = true
        end
    end

    for _, actor in ipairs(TS.Actors.GetAll()) do
        local current = TS.Dialogues.Get(TS.Actors.GetDialogue(actor))
        local occupied = activeActors[actor] == true and current ~= nil and current.settings.use_limit == true
        TS.Actors.SetBusy(actor, occupied)
    end
end

local function notify(player, code)
    if not IsValid(player) then
        return
    end
    net.Start("ts_notice")
    net.WriteString(code)
    net.Send(player)
end

local function hasLineOfSight(player, actor)
    if TS.Config.require_line_of_sight ~= true or not isfunction(util.TraceLine) then
        return true
    end
    local trace = util.TraceLine({
        start = player:EyePos(),
        endpos = actor:WorldSpaceCenter(),
        filter = player,
        mask = MASK_VISIBLE,
    })
    return not trace.Hit or trace.Entity == actor
end

local function isValidState(player, actor, distance, requireSight)
    return IsValid(player)
        and player:Alive()
        and IsValid(actor)
        and TS.Actors.IsActor(actor)
        and player:GetPos():DistToSqr(actor:GetPos()) <= distance * distance
        and (requireSight ~= true or hasLineOfSight(player, actor))
end

local function isCurrentSessionDocument(session)
    if not session or not istable(session.doc) then
        return false
    end
    local current = TS.Dialogues.Get(session.doc.id)
    return current == session.doc
        and current.meta
        and tonumber(current.meta.revision) == tonumber(session.revision)
end

local function newToken(player, session)
    tokenSequence = tokenSequence + 1
    return util.SHA256(table.concat({
        player:SteamID64(),
        tostring(SysTime()),
        tostring(tokenSequence),
        tostring(session and session.node or ""),
        tostring(math.random()),
    }, ":"))
end

local function meetsConditions(context, entries, resultCache)
    for index, entry in ipairs(entries or {}) do
        if not istable(entry) or not isstring(entry.id) then
            return false
        end
        local definition = TS.Conditions.Registry[entry.id]

        if not definition then
            return false
        end

        local validParameters = TS.Validation.ValidateParams(definition.params, entry.params)

        if not validParameters then
            return false
        end

        local result = definition.cache_result and resultCache and resultCache[index]
        local succeeded = true
        if result == nil then
            succeeded, result = TS.Utils.SafeCall("condition " .. entry.id, definition.run, context, entry.params or {})
            if succeeded and definition.cache_result and resultCache then
                resultCache[index] = not not result
            end
        end

        if not succeeded or not result then
            return false
        end
    end

    return true
end

local switchDepth = setmetatable({}, { __mode = "k" })
local function switchDialogue(player, session, dialogueID)
    if not TS.Dialogues.IsDependencyCurrent(session and session.doc, dialogueID) then
        TS.Runtime.Stop(player, "dialogue_dependency_changed")
        return false
    end
    local depth = (switchDepth[player] or 0) + 1
    if depth > 8 then
        TS.Runtime.Stop(player, "switch_loop")
        return false
    end
    switchDepth[player] = depth
    local actor = session.actor
    TS.Runtime.Stop(player, "switched")
    local started = TS.Runtime.Start(player, actor, dialogueID)
    switchDepth[player] = depth > 1 and depth - 1 or nil
    return started
end

local actionSequence = 0
local function isPromise(value)
    return istable(value) and isfunction(value.Then)
end

local function actionResultOK(value)
    return value ~= false and not (istable(value) and value.success == false)
end

local function actionCost(definition, params)
    local cost = math.max(tonumber(definition.action_cost) or 1, 1)
    if isstring(definition.cost_param) then
        local value = istable(params) and tonumber(params[definition.cost_param]) or nil
        if value then
            cost = math.max(cost, math.max(value, 0) * math.max(tonumber(definition.cost_multiplier) or 1, 0))
        end
    end
    return cost
end

local function prepareActions(context, entries)
    entries = entries or {}
    local maximum = math.Clamp(math.floor(tonumber(TS.Config.max_action_entries) or 16), 1, 64)
    if not istable(entries) or #entries > maximum then
        return nil, "too_many_actions"
    end

    local prepared = {}
    local cost = 0
    for index = 1, #entries do
        local entry = entries[index]
        if not istable(entry) or not isstring(entry.id) then
            return nil, "invalid_action"
        end
        local definition = TS.Actions.Registry[entry.id]
        if not definition then
            return nil, "unknown_action"
        end
        local validParameters = TS.Validation.ValidateParams(definition.params, entry.params)
        if not validParameters then
            return nil, "invalid_action_parameters"
        end
        cost = cost + actionCost(definition, entry.params)
        if cost > math.Clamp(tonumber(TS.Config.max_action_cost) or 64, 1, 1024) then
            return nil, "action_budget"
        end
        prepared[index] = { entry = entry, definition = definition }
    end

    for _, preparedEntry in ipairs(prepared) do
        local definition = preparedEntry.definition
        if isfunction(definition.preflight) then
            local called, result = TS.Utils.SafeCall(
                "action preflight " .. preparedEntry.entry.id,
                definition.preflight,
                context,
                preparedEntry.entry.params or {}
            )
            if not called or not actionResultOK(result) then
                return nil, "action_preflight"
            end
        end
    end

    return prepared
end

local function waitForPromise(context, promise, callback)
    actionSequence = actionSequence + 1
    local timerName = "Talksmith.ActionPromise." .. actionSequence
    local finished = false
    local function finish(ok)
        if finished then return end
        finished = true
        timer.Remove(timerName)
        callback(ok)
    end
    timer.Create(timerName, 15, 1, function()
        TS.Logging.Log(0, "integration action promise timed out")
        finish(false)
    end)
    local ok = pcall(function()
        promise:Then(
            function(value) finish(actionResultOK(value)) end,
            function(reason)
                TS.Logging.Log(0, "integration action promise rejected: " .. tostring(reason))
                finish(false)
            end
        )
    end)
    if not ok then finish(false) end
end

local function executeActions(context, entries, done)
    entries = entries or {}
    local completed = false
    local function finish(ok)
        if completed then return end
        completed = true
        done(ok)
    end
    local prepared, prepareError = prepareActions(context, entries)
    if not prepared then
        TS.Logging.Log(0, "Rejected action sequence: " .. tostring(prepareError))
        return finish(false)
    end
    local transaction, journalError = TS.Runtime.ActionJournal.Begin(context, entries)
    if not transaction then
        TS.Logging.Log(0, "Rejected action sequence: " .. tostring(journalError))
        return finish(false)
    end
    if transaction.complete then
        return finish(true)
    end

    local function step(index)
        if index > #prepared then
            if not TS.Runtime.ActionJournal.Complete(transaction) then
                TS.Logging.Log(0, "Could not complete action journal")
                return finish(false)
            end
            return finish(true)
        end
        if context.session
            and (TS.Runtime.Sessions[context.player] ~= context.session or not isCurrentSessionDocument(context.session))
        then
            return finish(false)
        end

        local preparedEntry = prepared[index]
        local entry = preparedEntry.entry
        local definition = preparedEntry.definition
        if transaction.enabled and transaction.record.states[tostring(index)] == "done" then
            return step(index + 1)
        end
        if not TS.Runtime.ActionJournal.Mark(transaction, index, "running") then
            return finish(false)
        end

        local succeeded, result = TS.Utils.SafeCall("action " .. entry.id, definition.run, context, entry.params or {})
        if not succeeded or not actionResultOK(result) then
            TS.Runtime.ActionJournal.Mark(transaction, index, "failed")
            return finish(false)
        end
        if isPromise(result) then
            return waitForPromise(context, result, function(ok)
                if not ok then
                    TS.Runtime.ActionJournal.Mark(transaction, index, "failed")
                    return finish(false)
                end
                if not TS.Runtime.ActionJournal.Mark(transaction, index, "done") then
                    return finish(false)
                end
                hook.Run("Talksmith.ActionExecuted", context.player, entry.id)
                step(index + 1)
            end)
        end
        if not TS.Runtime.ActionJournal.Mark(transaction, index, "done") then
            return finish(false)
        end
        hook.Run("Talksmith.ActionExecuted", context.player, entry.id)
        return step(index + 1)
    end
    step(1)
end

local function sendNodePayload(player, session, node, context)
    local options = {}
    session.visible = {}

    for _, option in ipairs(node.options) do
        local conditionCache = {}
        if meetsConditions(context, option.conditions, conditionCache) then
            session.visible[#session.visible + 1] = { option = option, conditionCache = conditionCache }
            options[#options + 1] = TS.Utils.ClampString(TS.Integrations.ResolveVariables(option.text, context), 512)
        end
    end

    if #options == 0 then
        TS.Runtime.Stop(player, "no_options")
        return false
    end

    session.token = newToken(player, session)
    session.lastActivity = CurTime()

    net.Start("ts_dialogue_node")
    net.WriteString(session.token)
    net.WriteString(TS.Utils.ClampString(TS.Actors.GetName(session.actor), 128))
    net.WriteString(TS.Utils.ClampString(TS.Actors.GetSubtitle(session.actor), 128))
    net.WriteString(TS.Utils.ClampString(TS.Integrations.ResolveVariables(node.text, context), 4096))
    local theme = session.doc.settings.theme
    net.WriteString(TS.Utils.InList(TS.Config.allowed_themes, theme) and theme or "default")
    net.WriteString(session.doc.id)
    net.WriteString(session.node)
    local nodeSound = isstring(node.sound) and TS.Utils.IsSoundAllowed(node.sound) and node.sound or ""
    net.WriteString(nodeSound)
    net.WriteEntity(session.actor)
    net.WriteUInt(#options, 3)

    for _, optionText in ipairs(options) do
        net.WriteString(optionText)
    end

    net.Send(player)

    if
        isstring(node.sound)
        and node.sound ~= ""
        and not TS.Utils.IsRemoteAudioURL(node.sound)
        and TS.Utils.IsSoundAllowed(node.sound)
        and IsValid(session.actor)
    then
        session.actor:EmitSound(node.sound)
    end

    if isstring(node.gesture) and node.gesture ~= "" and IsValid(session.actor) and session.actor.PlayGesture then
        session.actor:PlayGesture(node.gesture)
    end

    hook.Run("Talksmith.NodeEntered", player, session.actor, session.doc.id, session.node)
    return true
end

function TS.Runtime.Advance(player)
    local session = TS.Runtime.Sessions[player]
    if not session or session.pending then return false end
    if not isCurrentSessionDocument(session) then
        return TS.Runtime.Stop(player, "document_changed")
    end
    local node = session.doc.nodes[session.node]
    if not node then return TS.Runtime.Stop(player, "missing_node") end

    local context = {
        player = player,
        actor = session.actor,
        session = session,
        dialogue_id = session.doc.id,
        node_id = session.node,
        action_scope = "node:" .. tostring(session.node),
    }
    local result = true
    session.pending = true
    executeActions(context, node.actions, function(ok)
        if TS.Runtime.Sessions[player] ~= session or not IsValid(session.actor) then result = false; return end
        if not isCurrentSessionDocument(session) then
            result = false
            TS.Runtime.Stop(player, "document_changed")
            return
        end
        session.pending = false
        if not ok then result = false; TS.Runtime.Stop(player, "action_error"); return end
        if context.close then result = false; TS.Runtime.Stop(player, "completed"); return end
        if context.open then result = switchDialogue(player, session, context.open); return end
        result = sendNodePayload(player, session, node, context)
    end)
    return result
end

function TS.Runtime.Start(player, actor, dialogueID)
    dialogueID = TS.Utils.SafeID(dialogueID or "")

    local document = TS.Dialogues.Get(dialogueID)
    local distance = document and math.Clamp(document.settings.interact_distance or TS.Config.interact_distance, 64, 512)
        or 0

    if not document or not isValidState(player, actor, distance, true) or TS.Runtime.Sessions[player] then
        return false
    end

    if document.settings.use_limit == true and TS.Runtime.GetActorSession(actor, player) then
        TS.Actors.RefreshBusy(actor)
        notify(player, "busy")
        hook.Run("Talksmith.DialogueStartRejected", player, actor, dialogueID, "busy")
        return false
    end

    if hook.Run("Talksmith.CanStartDialogue", player, actor, dialogueID) == false then
        return false
    end

    -- core.open_dialogue retains the same entity, so refresh the target
    -- dialogue's model, appearance and idle animation before entering its node.
    if TS.Actors.ApplyDialogueAppearance then
        TS.Actors.ApplyDialogueAppearance(actor, document.settings)
    end

    local now = CurTime()
    TS.Runtime.Sessions[player] = {
        player = player,
        actor = actor,
        doc = document,
        node = document.start,
        token = "",
        revision = document.meta and document.meta.revision or 0,
        distance = distance,
        last = 0,
        createdAt = now,
        lastActivity = now,
    }
    TS.Actors.RefreshBusy(actor)

    local starts = {}
    local randomStarts = document.settings.start_random or {}
    local randomLimit = math.Clamp(math.floor(tonumber(TS.Config.max_random_targets) or 64), 1, 256)
    for index = 1, math.min(#randomStarts, randomLimit) do
        local id = randomStarts[index]
        if isstring(id) and document.nodes[id] then
            starts[#starts + 1] = id
        end
    end
    if #starts > 0 then
        TS.Runtime.Sessions[player].node = starts[math.random(#starts)]
    end

    local createdSession = TS.Runtime.Sessions[player]
    hook.Run("Talksmith.DialogueStarted", player, actor, dialogueID)
    local shown = TS.Runtime.Advance(player)
    if TS.Runtime.Sessions[player] ~= createdSession then
        return TS.Runtime.Sessions[player] ~= nil
    end
    if not shown then
        return false
    end
    return true
end

function TS.Runtime.Stop(player, reason)
    local session = TS.Runtime.Sessions[player]

    if not session then
        return
    end

    TS.Runtime.Sessions[player] = nil
    TS.Actors.RefreshBusy(session.actor)

    -- A transition can temporarily apply another dialogue's model and idle
    -- sequence to this Actor. When the last session ends, restore the Actor's
    -- own linked dialogue so its world appearance never stays stale.
    if not TS.Runtime.GetActorSession(session.actor) then
        local homeDialogue = TS.Dialogues.Get(TS.Actors.GetDialogue(session.actor))
        if homeDialogue and TS.Actors.ApplyDialogueAppearance then
            TS.Actors.ApplyDialogueAppearance(session.actor, homeDialogue.settings)
        end
    end

    if IsValid(player) then
        net.Start("ts_dialogue_close")
        net.WriteString(reason or "ended")
        net.Send(player)
    end

    hook.Run("Talksmith.DialogueEnded", player, session.actor, reason)
end

function TS.Runtime.SelectOption(player, token, index)
    local session = TS.Runtime.Sessions[player]

    if
        not session
        or not TS.Network.Allow(player, "choice", TS.Config.choice_cooldown)
        or token ~= session.token
        or session.pending
        or not isCurrentSessionDocument(session)
        or not isValidState(player, session.actor, session.distance, true)
    then
        return
    end

    local visible = session.visible[index]
    local option = visible and visible.option

    if not option then
        return TS.Runtime.Stop(player, "invalid_choice")
    end

    local context = {
        player = player,
        actor = session.actor,
        session = session,
        dialogue_id = session.doc.id,
        node_id = session.node,
        option_index = index,
        action_scope = "option:" .. tostring(session.node) .. ":" .. tostring(index),
    }

    if not meetsConditions(context, option.conditions, visible.conditionCache) then
        return TS.Runtime.Stop(player, "rejected")
    end
    session.lastActivity = CurTime()
    session.pending = true
    executeActions(context, option.actions, function(ok)
        if TS.Runtime.Sessions[player] ~= session or not IsValid(session.actor) then return end
        if not isCurrentSessionDocument(session) then
            return TS.Runtime.Stop(player, "document_changed")
        end
        session.pending = false
        if not ok then return TS.Runtime.Stop(player, "rejected") end
        hook.Run("Talksmith.OptionSelected", player, session.actor, index)
        if isstring(option.gesture) and option.gesture ~= "" and session.actor.PlayGesture then
            session.actor:PlayGesture(option.gesture)
        end
        if context.close then return TS.Runtime.Stop(player, "completed") end
        if context.open then return switchDialogue(player, session, context.open) end
        local targets = {}
        local randomTargets = option.next_random or {}
        local randomLimit = math.Clamp(math.floor(tonumber(TS.Config.max_random_targets) or 64), 1, 256)
        for targetIndex = 1, math.min(#randomTargets, randomLimit) do
            local id = randomTargets[targetIndex]
            if isstring(id) and session.doc.nodes[id] then targets[#targets + 1] = id end
        end
        local nextNode = #targets > 0 and targets[math.random(#targets)] or option.next
        if not nextNode then return TS.Runtime.Stop(player, "completed") end
        session.node = nextNode
        TS.Runtime.Advance(player)
    end)
    return true
end

timer.Create("Talksmith.SessionGuard", 0.5, 0, function()
    local now = CurTime()
    local idleTimeout = math.Clamp(tonumber(TS.Config.session_idle_timeout) or 90, 15, 3600)
    local maximumDuration = math.Clamp(tonumber(TS.Config.session_max_duration) or 600, idleTimeout, 7200)
    for player, session in pairs(TS.Runtime.Sessions) do
        if not isCurrentSessionDocument(session) then
            TS.Runtime.Stop(player, "document_changed")
        elseif now - (session.createdAt or now) > maximumDuration then
            TS.Runtime.Stop(player, "session_expired")
        elseif now - (session.lastActivity or now) > idleTimeout then
            TS.Runtime.Stop(player, "session_timeout")
        elseif not isValidState(player, session.actor, session.distance, true) then
            TS.Runtime.Stop(player, "out_of_range")
        end
    end
end)

hook.Add("PlayerDeath", "Talksmith.StopDeath", function(player)
    TS.Runtime.Stop(player, "death")
end)

hook.Add("PlayerDisconnected", "Talksmith.StopLeave", function(player)
    TS.Runtime.Stop(player, "disconnected")
end)

local function stopDocumentSessions(dialogueID, reason)
    local players = {}
    for player, session in pairs(TS.Runtime.Sessions) do
        local dependencies = session.doc and session.doc.meta and session.doc.meta.open_dialogue_revisions
        if session.doc
            and (session.doc.id == dialogueID or istable(dependencies) and dependencies[dialogueID] ~= nil)
        then
            players[#players + 1] = player
        end
    end
    for _, player in ipairs(players) do
        TS.Runtime.Stop(player, reason)
    end
end

hook.Add("Talksmith.DialogueSaved", "Talksmith.InvalidateSavedSessions", function(dialogueID)
    stopDocumentSessions(dialogueID, "document_changed")
end)

hook.Add("Talksmith.DialogueDeleted", "Talksmith.InvalidateDeletedSessions", function(dialogueID)
    stopDocumentSessions(dialogueID, "document_deleted")
end)
