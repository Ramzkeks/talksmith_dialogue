local TS = Talksmith

function TS.Integrations.Refresh(id)
    id = TS.Utils.SafeID(id)
    local integration = id and TS.Integrations.Registry[id]
    if not integration then
        return false
    end

    local enabled = integration.automatic == true or TS.Config.integrations[id] == true
    local status = enabled and "unavailable" or "disabled"
    local reason = enabled and "addon_missing" or "manual_disabled"

    if enabled and not isfunction(integration.detect) then
        status, reason = "available", ""
    elseif enabled then
        local ok, detected, detectedReason = TS.Utils.SafeCall("detect integration " .. id, integration.detect)
        if not ok then
            status, reason = "error", "detection_failed"
        elseif detected then
            status, reason = "available", ""
        elseif detectedReason == "loading" then
            status, reason = "loading", "addon_loading"
        end
    end

    local previousStatus = integration.status
    local changed = integration.enabled ~= enabled
        or integration.status ~= status
        or integration.reason ~= reason

    integration.enabled = enabled
    integration.status = status
    integration.reason = reason

    if changed then
        hook.Run("Talksmith.IntegrationStatusChanged", id, status, reason)
    end
    if status == "available" and previousStatus ~= "available" then
        hook.Run("Talksmith.IntegrationLoaded", id, integration)
    end

    return true, status, reason
end

function TS.Integrations.RefreshAll()
    for id in pairs(TS.Integrations.Registry) do
        TS.Integrations.Refresh(id)
    end

    hook.Run("Talksmith.IntegrationsReady", TS.Integrations.Registry)
end

function TS.Integrations.GetCatalog()
    local out = {}
    for id, integration in pairs(TS.Integrations.Registry) do
        local actions, conditions, variables, providers = 0, 0, 0, 0
        local providerKinds = {}
        for _, definition in pairs(TS.Actions.Registry) do
            if definition.integration == id then
                actions = actions + 1
            end
        end
        for _, definition in pairs(TS.Conditions.Registry) do
            if definition.integration == id then
                conditions = conditions + 1
            end
        end
        for _, definition in pairs(TS.Integrations.Variables) do
            if definition.integration == id then
                variables = variables + 1
            end
        end
        for kind, group in pairs(TS.Providers.Registry) do
            for _, definition in pairs(group) do
                if definition.integration == id then
                    providers = providers + 1
                    providerKinds[kind] = true
                end
            end
        end
        local providerKindList = {}
        for kind in pairs(providerKinds) do
            providerKindList[#providerKindList + 1] = kind
        end
        table.sort(providerKindList)
        out[id] = {
            id = id,
            name = integration.name,
            version = integration.version,
            category = integration.category,
            priority = integration.priority,
            automatic = integration.automatic == true,
            enabled = integration.enabled == true,
            status = integration.status,
            reason = integration.reason,
            capabilities = integration.capabilities or {},
            actions = actions,
            conditions = conditions,
            variables = variables,
            providers = providers,
            provider_kinds = providerKindList,
        }
    end
    return out
end

hook.Add("InitPostEntity", "Talksmith.RefreshEnabledIntegrations", function()
    TS.Integrations.RefreshAll()
end)
hook.Add("OnReloaded", "Talksmith.RefreshEnabledIntegrations", function()
    timer.Simple(0, function()
        TS.Integrations.RefreshAll()
    end)
end)
