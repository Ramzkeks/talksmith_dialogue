local TS = Talksmith

TS.Integrations.Registry = TS.Integrations.Registry or {}
TS.Integrations.Variables = TS.Integrations.Variables or {}
TS.Providers.Registry = TS.Providers.Registry or {}
TS.API.Integrations = TS.API.Integrations or {}
TS.Config.integrations = istable(TS.Config.integrations) and TS.Config.integrations or {}
TS.Integrations.RegistrationSources = TS.Integrations.RegistrationSources or {}
TS.Integrations.ActionSources = TS.Integrations.ActionSources or {}
TS.Integrations.ConditionSources = TS.Integrations.ConditionSources or {}
TS.Integrations.VariableSources = TS.Integrations.VariableSources or {}
TS.Providers.RegistrationSources = TS.Providers.RegistrationSources or {}

local function registrationSource(level)
    local info = debug and isfunction(debug.getinfo) and debug.getinfo(level or 3, "S") or nil
    return info and tostring(info.source or info.short_src) or "unknown"
end

local function acceptsSource(sources, id, source)
    if sources[id] and sources[id] ~= source then
        if TS.Logging and TS.Logging.Log then
            TS.Logging.Log(0, "Rejected duplicate integration registry id " .. tostring(id) .. " from " .. source)
        end
        return false
    end
    sources[id] = source
    return true
end

local function copyFields(dst, src)
    for key, value in pairs(src or {}) do
        dst[key] = value
    end

    return dst
end

function TS.Integrations.Register(id, definition)
    id = TS.Utils.SafeID(id)
    if not id or not istable(definition) then
        return false
    end
    if not acceptsSource(TS.Integrations.RegistrationSources, id, registrationSource(3)) then
        return false
    end

    local old = TS.Integrations.Registry[id]
    local manifest = copyFields(old or {}, definition)
    manifest.id = id
    manifest.name = tostring(manifest.name or id)
    manifest.version = tostring(manifest.version or "unknown")
    manifest.category = tostring(manifest.category or "other")
    manifest.capabilities = istable(manifest.capabilities) and manifest.capabilities or {}
    manifest.priority = tonumber(manifest.priority) or 0
    manifest.automatic = manifest.automatic == true
    manifest.enabled = old and old.enabled == true or false
    manifest.status = old and old.status or "disabled"
    manifest.reason = old and old.reason or ""
    TS.Integrations.Registry[id] = manifest
    return true
end

function TS.Integrations.IsAvailable(id)
    local integration = TS.Integrations.Registry[id]
    return integration ~= nil and integration.status == "available"
end

function TS.Integrations.Get(id)
    return TS.Integrations.Registry[TS.Utils.SafeID(id or "")]
end

function TS.Integrations.Enable(id)
    if not SERVER or not TS.Integrations.SetEnabled then
        return false, "server_only"
    end
    return TS.Integrations.SetEnabled(id, true)
end

function TS.Integrations.Disable(id)
    if not SERVER or not TS.Integrations.SetEnabled then
        return false, "server_only"
    end
    return TS.Integrations.SetEnabled(id, false)
end

local function namespaced(integrationID, localID)
    integrationID, localID = TS.Utils.SafeID(integrationID), TS.Utils.SafeID(localID)
    if not integrationID or not localID then
        return nil
    end

    return integrationID .. "." .. localID
end

function TS.Integrations.RegisterAction(integrationID, localID, definition)
    integrationID = TS.Utils.SafeID(integrationID)
    if not integrationID then
        return false
    end

    local id = namespaced(integrationID, localID)
    if not id or not istable(definition) or not isfunction(definition.run) then
        return false
    end
    if not acceptsSource(TS.Integrations.ActionSources, id, registrationSource(3)) then
        return false
    end

    local callback = definition.run
    definition.integration = integrationID
    definition.category = definition.category
        or (TS.Integrations.Registry[integrationID] and TS.Integrations.Registry[integrationID].category)
    definition.run = function(context, params)
        if not TS.Integrations.IsAvailable(integrationID) then
            return false
        end

        return callback(context, params)
    end
    return TS.Actions.Register(id, definition)
end

function TS.Integrations.RegisterCondition(integrationID, localID, definition)
    integrationID = TS.Utils.SafeID(integrationID)
    if not integrationID then
        return false
    end

    local id = namespaced(integrationID, localID)
    if not id or not istable(definition) or not isfunction(definition.run) then
        return false
    end
    if not acceptsSource(TS.Integrations.ConditionSources, id, registrationSource(3)) then
        return false
    end

    local callback = definition.run
    definition.integration = integrationID
    definition.category = definition.category
        or (TS.Integrations.Registry[integrationID] and TS.Integrations.Registry[integrationID].category)
    definition.run = function(context, params)
        if not TS.Integrations.IsAvailable(integrationID) then
            return false
        end

        return callback(context, params)
    end
    return TS.Conditions.Register(id, definition)
end

function TS.Providers.Register(kind, id, definition)
    kind, id = TS.Utils.SafeID(kind), TS.Utils.SafeID(id)
    if not kind or not id or not istable(definition) then
        return false
    end

    local sourceKey = kind .. "." .. id
    if not acceptsSource(TS.Providers.RegistrationSources, sourceKey, registrationSource(3)) then
        return false
    end

    TS.Providers.Registry[kind] = TS.Providers.Registry[kind] or {}
    definition.id, definition.kind = id, kind
    definition.priority = tonumber(definition.priority) or 0
    TS.Providers.Registry[kind][id] = definition
    return true
end

function TS.Providers.Get(kind, id, method)
    kind = TS.Utils.SafeID(kind)
    if not kind then
        return nil
    end
    method = isstring(method) and method or nil

    local providers = TS.Providers.Registry[kind] or {}
    if id and id ~= "" and id ~= "auto" then
        local provider = providers[id]
        if provider
            and (not provider.integration or TS.Integrations.IsAvailable(provider.integration))
            and (not method or isfunction(provider[method]))
        then
            return provider
        end

        return nil
    end
    local only
    for _, provider in pairs(providers) do
        if (not provider.integration or TS.Integrations.IsAvailable(provider.integration))
            and (not method or isfunction(provider[method]))
        then
            if only then
                return nil
            end
            only = provider
        end
    end
    return only
end

function TS.Providers.HasAvailable(kind, method)
    kind = TS.Utils.SafeID(kind)
    if not kind then
        return false
    end
    method = isstring(method) and method or nil

    for _, provider in pairs(TS.Providers.Registry[kind] or {}) do
        if (not provider.integration or TS.Integrations.IsAvailable(provider.integration))
            and (not method or isfunction(provider[method]))
        then
            return true
        end
    end

    return false
end

function TS.Providers.GetActive(kind, method)
    return TS.Providers.Get(kind, "auto", method)
end

function TS.Providers.IsAvailable(kind, id, method)
    return TS.Providers.Get(kind, id, method) ~= nil
end

function TS.Providers.CountAvailable(kind, method)
    kind = TS.Utils.SafeID(kind)
    if not kind then
        return 0
    end
    method = isstring(method) and method or nil

    local providers = TS.Providers.Registry[kind]
    local clientCatalog = false
    if not providers and TS.Editor.Catalog and TS.Editor.Catalog.providers then
        providers = TS.Editor.Catalog.providers[kind]
        clientCatalog = true
    end

    local count = 0
    for _, provider in pairs(providers or {}) do
        local available = clientCatalog
            and provider.available ~= false
            or not clientCatalog
                and (not provider.integration or TS.Integrations.IsAvailable(provider.integration))
        local supports = not method
            or clientCatalog and (provider.methods == nil or provider.methods[method] == true)
            or not clientCatalog and isfunction(provider[method])
        if available and supports then
            count = count + 1
        end
    end
    return count
end

function TS.Integrations.RegisterVariable(id, definition)
    id = TS.Utils.SafeRefID(id)
    if not id or not istable(definition) or not isfunction(definition.resolve) then
        return false
    end
    if not acceptsSource(TS.Integrations.VariableSources, id, registrationSource(3)) then
        return false
    end

    definition.id = id
    TS.Integrations.Variables[id] = definition
    return true
end

function TS.Integrations.ResolveVariables(text, context)
    if not isstring(text) then
        return ""
    end

    local limit = math.Clamp(math.floor(tonumber(TS.Config.max_variable_resolutions) or 64), 1, 256)
    local resolved = string.gsub(text, "{([a-zA-Z0-9_%.%-]+):?([^}]*)}", function(rawID, argument)
        local id = TS.Utils.SafeRefID(rawID)
        local variable = id and TS.Integrations.Variables[id]
        if not variable or (variable.integration and not TS.Integrations.IsAvailable(variable.integration)) then
            return "{" .. rawID .. (argument ~= "" and ":" .. argument or "") .. "}"
        end
        local ok, result = TS.Utils.SafeCall("variable " .. id, variable.resolve, context or {}, TS.Utils.ClampString(argument, 128))
        if not ok or result == nil then
            return ""
        end

        return TS.Utils.ClampString(tostring(result), 512)
    end, limit)
    return resolved
end

TS.API.Integrations.Register = TS.Integrations.Register
TS.API.Integrations.RegisterAction = TS.Integrations.RegisterAction
TS.API.Integrations.RegisterCondition = TS.Integrations.RegisterCondition
TS.API.Integrations.RegisterProvider = TS.Providers.Register
TS.API.Integrations.RegisterVariable = TS.Integrations.RegisterVariable
