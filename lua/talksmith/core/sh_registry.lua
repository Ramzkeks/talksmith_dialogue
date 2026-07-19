local TS = Talksmith
TS.Actions.Registry = TS.Actions.Registry or {}
TS.Conditions.Registry = TS.Conditions.Registry or {}
local actionSources = TS.Actions.RegistrationSources or {}
local conditionSources = TS.Conditions.RegistrationSources or {}
TS.Actions.RegistrationSources = actionSources
TS.Conditions.RegistrationSources = conditionSources

local function callerSource()
    local info = debug and isfunction(debug.getinfo) and debug.getinfo(4, "S") or nil
    return info and tostring(info.source or info.short_src) or "unknown"
end

local function register(dst, sources, id, def)
    id = (TS.Utils.SafeRefID and TS.Utils.SafeRefID(id)) or TS.Utils.SafeID(id)
    if not id or not istable(def) or not isfunction(def.run) then
        return false
    end
    local source = callerSource()
    if dst[id] and sources[id] and sources[id] ~= source then
        if TS.Logging and TS.Logging.Log then
            TS.Logging.Log(0, "Rejected duplicate registry id " .. id .. " from " .. source)
        end
        return false
    end
    def.id, def.params = id, def.params or {}
    dst[id] = def
    sources[id] = source
    return true
end
function TS.Actions.Register(id, def)
    if istable(def)
        and def.safe ~= true
        and def.dangerous ~= true
        and not isstring(def.permission)
    then
        def.dangerous = true
        if TS.Logging and TS.Logging.Log then
            TS.Logging.Log(1, "Action " .. tostring(id) .. " has no security classification; defaulting to dangerous")
        end
    end
    return register(TS.Actions.Registry, actionSources, id, def)
end
function TS.Conditions.Register(id, def)
    return register(TS.Conditions.Registry, conditionSources, id, def)
end

function TS.Actions.Get(id)
    return TS.Actions.Registry[id]
        or (TS.Editor.Catalog and TS.Editor.Catalog.actions and TS.Editor.Catalog.actions[id])
        or nil
end
function TS.Conditions.Get(id)
    return TS.Conditions.Registry[id]
        or (TS.Editor.Catalog and TS.Editor.Catalog.conditions and TS.Editor.Catalog.conditions[id])
        or nil
end

function TS.Actions.Execute(id, context, params)
    local definition = TS.Actions.Get(id)
    if not definition then
        return false, "unknown_action"
    end
    local valid, reason = TS.Validation.ValidateParams(definition.params, params)
    if not valid then
        return false, reason
    end
    local called, result = TS.Utils.SafeCall("action " .. tostring(id), definition.run, context or {}, params or {})
    return called and result ~= false, result
end

function TS.Conditions.Evaluate(id, context, params)
    local definition = TS.Conditions.Get(id)
    if not definition then
        return false, "unknown_condition"
    end
    local valid, reason = TS.Validation.ValidateParams(definition.params, params)
    if not valid then
        return false, reason
    end
    local called, result = TS.Utils.SafeCall("condition " .. tostring(id), definition.run, context or {}, params or {})
    return called and not not result, result
end

local function finiteNumber(value)
    return isnumber(value) and value == value and value ~= math.huge and value ~= -math.huge
end

function TS.Validation.ValidateParams(schema, values)
    if values ~= nil and not istable(values) then
        return false, "parameters must be an object"
    end
    values = values or {}
    schema = schema or {}
    if not istable(schema) then
        return false, "parameter schema is invalid"
    end

    for key, value in pairs(values) do
        local rule = schema[key]
        if not rule then
            return false, tostring(key) .. " is not allowed"
        end
        if not (isbool(value) or isnumber(value) or isstring(value)) then
            return false, tostring(key) .. " must be a scalar"
        end
        if isnumber(value) and not finiteNumber(value) then
            return false, tostring(key) .. " must be finite"
        end
    end
    for key, rule in pairs(schema) do
        local label = tostring(key)
        if not istable(rule) then
            return false, label .. " has an invalid rule"
        end
        if rule.type ~= nil and rule.type ~= "boolean" and rule.type ~= "number" and rule.type ~= "string" then
            return false, label .. " has an invalid type"
        end
        if rule.options ~= nil and not istable(rule.options) then
            return false, label .. " has invalid options"
        end
        if rule.integer ~= nil and not isbool(rule.integer) then
            return false, label .. " has an invalid integer flag"
        end
        if rule.min ~= nil and not finiteNumber(rule.min) then
            return false, label .. " has an invalid minimum"
        end
        if rule.max ~= nil and not finiteNumber(rule.max) then
            return false, label .. " has an invalid maximum"
        end
        if rule.min ~= nil and rule.max ~= nil and rule.min > rule.max then
            return false, label .. " has invalid bounds"
        end
        local v = values[key]
        if rule.required and v == nil then
            return false, label .. " is required"
        end
        if v ~= nil and rule.type and type(v) ~= rule.type then
            return false, label .. " has wrong type"
        end
        if v ~= nil and not rule.type and not (isbool(v) or isnumber(v) or isstring(v)) then
            return false, label .. " must be a scalar"
        end
        if isstring(v) and rule.max and #v > rule.max then
            return false, label .. " is too long"
        end
        if isnumber(v) and rule.min and v < rule.min then
            return false, label .. " is too small"
        end
        if isnumber(v) and rule.max and v > rule.max then
            return false, label .. " is too large"
        end
        if isnumber(v) and rule.integer and v ~= math.floor(v) then
            return false, label .. " must be an integer"
        end
        if v ~= nil and istable(rule.options) then
            local allowed = false
            for _, option in ipairs(rule.options) do
                local optionValue = istable(option) and option.value or option
                if optionValue == v then
                    allowed = true
                    break
                end
            end
            if not allowed then
                return false, label .. " is not an allowed option"
            end
        end
    end
    return true
end
