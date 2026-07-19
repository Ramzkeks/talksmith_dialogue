local TS = Talksmith
local ID = "wiremod"

local INPUT_COUNT = 8
local OUTPUT_COUNT = 8

TS.Integrations.Register(ID, {
    name = "Wiremod",
    category = "automation",
    priority = 95,
    capabilities = { "wire-io", "signals", "map-automation" },
    detect = function()
        return istable(WireLib)
            and isfunction(WireLib.CreateInputs)
            and isfunction(WireLib.CreateOutputs)
            and isfunction(WireLib.TriggerInput)
            and isfunction(WireLib.TriggerOutput)
            and isfunction(WireLib.Remove), "WireLib API"
    end,
})

local function isActor(entity)
    return TS.Actors.IsActor(entity)
end

local function canManageWire(player)
    return IsValid(player)
        and TS.Permissions.Has(player, "talksmith.wire.manage")
end

hook.Add("CanTool", "Talksmith.Wiremod.ProtectActorTools", function(player, trace)
    local entity = istable(trace) and trace.Entity or nil
    if isActor(entity) and not canManageWire(player) then
        return false
    end
end)

hook.Add("CanProperty", "Talksmith.Wiremod.ProtectActorProperties", function(player, _, entity)
    if isActor(entity) and not canManageWire(player) then
        return false
    end
end)

hook.Add("CanDrive", "Talksmith.Wiremod.ProtectActorDrive", function(player, entity)
    if isActor(entity) and not canManageWire(player) then
        return false
    end
end)

hook.Add("CanEditVariable", "Talksmith.Wiremod.ProtectActorVariables", function(entity, player)
    if isActor(entity) and not canManageWire(player) then
        return false
    end
end)

local function externalInput(entity, index)
    if not isActor(entity) then
        return 0
    end

    index = math.Clamp(math.floor(tonumber(index) or 0), 1, INPUT_COUNT)
    return tonumber(entity.TalksmithWireInputs and entity.TalksmithWireInputs[index]) or 0
end

local function customOutputName(index)
    index = math.Clamp(math.floor(tonumber(index) or 0), 1, OUTPUT_COUNT)
    return "CustomOutput" .. index
end

local function triggerOutput(entity, name, value, force)
    if
        not isActor(entity)
        or not entity.TalksmithWireReady
        or not istable(WireLib)
        or not isfunction(WireLib.TriggerOutput)
    then
        return false
    end

    WireLib.TriggerOutput(entity, name, value, nil, force == true)
    return true
end

local function pulseOutput(entity, name)
    if not triggerOutput(entity, name, 1, true) then
        return false
    end

    entity.TalksmithWirePulses = entity.TalksmithWirePulses or {}
    local sequence = (entity.TalksmithWirePulses[name] or 0) + 1
    entity.TalksmithWirePulses[name] = sequence
    timer.Simple(0, function()
        if
            isActor(entity)
            and entity.TalksmithWireReady
            and entity.TalksmithWirePulses
            and entity.TalksmithWirePulses[name] == sequence
        then
            triggerOutput(entity, name, 0, true)
        end
    end)
    return true
end

local function currentPlayer(entity)
    for player, session in pairs(TS.Runtime.Sessions or {}) do
        if session.actor == entity and IsValid(player) then
            return player
        end
    end

    return NULL
end

local function syncConversationOutputs(entity)
    if not isActor(entity) or not entity.TalksmithWireReady then
        return
    end

    local player = currentPlayer(entity)
    triggerOutput(entity, "Busy", IsValid(player) and 1 or 0)
    triggerOutput(entity, "Player", player)
end

local function closeActorDialogues(entity, reason)
    local players = {}
    for player, session in pairs(TS.Runtime.Sessions or {}) do
        if session.actor == entity then
            players[#players + 1] = player
        end
    end

    for _, player in ipairs(players) do
        TS.Runtime.Stop(player, reason or "wire_force_close")
    end
end

function TS.Actors.SetupWire(entity)
    if
        not isActor(entity)
        or not TS.Integrations.IsAvailable(ID)
        or not istable(WireLib)
        or not isfunction(WireLib.CreateInputs)
        or not isfunction(WireLib.CreateOutputs)
        or not isfunction(WireLib.TriggerInput)
        or not isfunction(WireLib.TriggerOutput)
    then
        return false
    end
    if entity.TalksmithWireReady then
        syncConversationOutputs(entity)
        return true
    end

    local inputs = {
        "Enabled",
        "Locked",
        "ForceClose",
    }
    for index = 1, INPUT_COUNT do
        inputs[#inputs + 1] = "ExternalValue" .. index
    end

    local outputs = {
        "Busy",
        "Player [ENTITY]",
        "DialogueStarted",
        "NodeChanged [STRING]",
        "OptionChosen",
        "DialogueEnded",
    }
    for index = 1, OUTPUT_COUNT do
        outputs[#outputs + 1] = "CustomOutput" .. index .. " [ANY]"
    end

    WireLib.CreateInputs(entity, inputs)
    WireLib.CreateOutputs(entity, outputs)
    entity.TalksmithWireInputs = {}
    entity.TalksmithWirePulses = {}
    entity.TalksmithWireForceClose = false
    entity.TalksmithWireEnabled = true
    entity.TalksmithWireLocked = false
    entity.TalksmithWireReady = true

    WireLib.TriggerInput(entity, "Enabled", 1)
    triggerOutput(entity, "Busy", 0)
    triggerOutput(entity, "Player", NULL)
    triggerOutput(entity, "DialogueStarted", 0)
    triggerOutput(entity, "NodeChanged", "")
    triggerOutput(entity, "OptionChosen", 0)
    triggerOutput(entity, "DialogueEnded", 0)
    for index = 1, OUTPUT_COUNT do
        triggerOutput(entity, customOutputName(index), 0)
    end
    syncConversationOutputs(entity)
    return true
end

function TS.Actors.RemoveWire(entity)
    if not entity or not entity.TalksmithWireReady then
        return
    end

    entity.TalksmithWireReady = nil
    entity.TalksmithWireInputs = nil
    entity.TalksmithWirePulses = nil
    entity.TalksmithWireForceClose = nil
    entity.TalksmithWireEnabled = nil
    entity.TalksmithWireLocked = nil
    if istable(WireLib) and isfunction(WireLib.Remove) then
        WireLib.Remove(entity)
    end
end

function TS.Actors.HandleWireInput(entity, name, value)
    if not isActor(entity) or not entity.TalksmithWireReady then
        return
    end

    value = tonumber(value) or 0
    if name == "Enabled" then
        entity.TalksmithWireEnabled = value > 0
        return
    end
    if name == "Locked" then
        entity.TalksmithWireLocked = value > 0
        return
    end
    if name == "ForceClose" then
        local active = value > 0
        if active and not entity.TalksmithWireForceClose then
            closeActorDialogues(entity)
        end
        entity.TalksmithWireForceClose = active
        return
    end

    local index = tonumber(string.match(name or "", "^ExternalValue(%d+)$"))
    if index and index >= 1 and index <= INPUT_COUNT then
        entity.TalksmithWireInputs = entity.TalksmithWireInputs or {}
        entity.TalksmithWireInputs[index] = value
    end
end

hook.Add("Talksmith.CanStartDialogue", "Talksmith.Wiremod.CanStart", function(_, entity)
    if
        TS.Integrations.IsAvailable(ID)
        and isActor(entity)
        and entity.TalksmithWireReady
        and (entity.TalksmithWireEnabled == false or entity.TalksmithWireLocked == true)
    then
        return false
    end
end)

hook.Add("Talksmith.DialogueStarted", "Talksmith.Wiremod.Started", function(player, entity)
    if not TS.Integrations.IsAvailable(ID) or not isActor(entity) then
        return
    end

    syncConversationOutputs(entity)
    triggerOutput(entity, "Player", player)
    pulseOutput(entity, "DialogueStarted")
end)

hook.Add("Talksmith.NodeEntered", "Talksmith.Wiremod.NodeChanged", function(_, entity, _, nodeID)
    if TS.Integrations.IsAvailable(ID) and isActor(entity) then
        triggerOutput(entity, "NodeChanged", tostring(nodeID or ""), true)
    end
end)

hook.Add("Talksmith.OptionSelected", "Talksmith.Wiremod.OptionChosen", function(_, entity, index)
    if TS.Integrations.IsAvailable(ID) and isActor(entity) then
        triggerOutput(entity, "OptionChosen", tonumber(index) or 0, true)
    end
end)

hook.Add("Talksmith.DialogueEnded", "Talksmith.Wiremod.Ended", function(_, entity)
    if not TS.Integrations.IsAvailable(ID) or not isActor(entity) then
        return
    end

    syncConversationOutputs(entity)
    pulseOutput(entity, "DialogueEnded")
end)

hook.Add("OnEntityCreated", "Talksmith.Wiremod.ActorCreated", function(entity)
    if not IsValid(entity) or entity:GetClass() ~= "talksmith_actor" then
        return
    end

    timer.Simple(0, function()
        if isActor(entity) then
            TS.Actors.SetupWire(entity)
        end
    end)
end)

hook.Add("Talksmith.IntegrationStatusChanged", "Talksmith.Wiremod.StatusChanged", function(id, status)
    if id ~= ID then
        return
    end

    for _, entity in ipairs(TS.Actors.GetAll()) do
        if status == "available" then
            TS.Actors.SetupWire(entity)
        else
            TS.Actors.RemoveWire(entity)
        end
    end
end)

local function numberedOptions(count)
    local out = {}
    for index = 1, count do
        out[index] = index
    end
    return out
end

local inputRule = {
    type = "number",
    required = true,
    integer = true,
    min = 1,
    max = INPUT_COUNT,
    options = numberedOptions(INPUT_COUNT),
}
local outputRule = {
    type = "number",
    required = true,
    integer = true,
    min = 1,
    max = OUTPUT_COUNT,
    options = numberedOptions(OUTPUT_COUNT),
}

TS.Integrations.RegisterCondition(ID, "input_equals", {
    name = "Wiremod: input equals value",
    params = {
        input = inputRule,
        value = { type = "number", required = true, min = -1000000000, max = 1000000000 },
    },
    run = function(context, params)
        return externalInput(context.actor, params.input) == params.value
    end,
})

TS.Integrations.RegisterCondition(ID, "input_greater", {
    name = "Wiremod: input is greater than value",
    params = {
        input = inputRule,
        value = { type = "number", required = true, min = -1000000000, max = 1000000000 },
    },
    run = function(context, params)
        return externalInput(context.actor, params.input) > params.value
    end,
})

TS.Integrations.RegisterCondition(ID, "input_active", {
    name = "Wiremod: input is active",
    params = { input = inputRule },
    run = function(context, params)
        return externalInput(context.actor, params.input) > 0
    end,
})

TS.Integrations.RegisterCondition(ID, "input_inactive", {
    name = "Wiremod: input is inactive",
    params = { input = inputRule },
    run = function(context, params)
        return externalInput(context.actor, params.input) <= 0
    end,
})

TS.Integrations.RegisterAction(ID, "set_output", {
    name = "Wiremod: set output",
    permission = "talksmith.wire.manage",
    params = {
        output = outputRule,
        value = { type = "number", required = true, min = -1000000000, max = 1000000000 },
    },
    run = function(context, params)
        return triggerOutput(context.actor, customOutputName(params.output), params.value, true)
    end,
})

TS.Integrations.RegisterAction(ID, "pulse_output", {
    name = "Wiremod: pulse output",
    permission = "talksmith.wire.manage",
    params = { output = outputRule },
    run = function(context, params)
        return pulseOutput(context.actor, customOutputName(params.output))
    end,
})

TS.Integrations.RegisterAction(ID, "send_string", {
    name = "Wiremod: send string",
    permission = "talksmith.wire.manage",
    params = {
        output = outputRule,
        text = { type = "string", required = true, max = 512 },
    },
    run = function(context, params)
        return triggerOutput(context.actor, customOutputName(params.output), params.text, true)
    end,
})

TS.Integrations.RegisterAction(ID, "pass_selected_answer", {
    name = "Wiremod: pass selected answer",
    permission = "talksmith.wire.manage",
    params = { output = outputRule },
    run = function(context, params)
        return triggerOutput(context.actor, customOutputName(params.output), context.option_index or 0, true)
    end,
})
