local TS = Talksmith
local ID = "sadmin"

TS.Integrations.Register(ID, {
    name = "sAdmin",
    category = "permissions",
    priority = 110,
    capabilities = { "permissions", "usergroups", "CAMI", "admin-mod" },
    detect = function()
        return istable(sAdmin)
            and istable(sAdmin.usergroups)
            and isfunction(sAdmin.hasPermission), "sAdmin API"
    end,
})

TS.Integrations.RegisterCondition(ID, "has_access", {
    name = "sAdmin: has permission",
    params = { access = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        local allowed = sAdmin.hasPermission(context.player, params.access)
        return allowed ~= nil and allowed ~= false
    end,
})

TS.Integrations.RegisterCondition(ID, "usergroup_is", {
    name = "sAdmin: user group is",
    params = { group = { type = "string", required = true, max = 64 } },
    run = function(context, params)
        return string.lower(context.player:GetUserGroup()) == string.lower(params.group)
    end,
})

TS.Integrations.RegisterCondition(ID, "can_edit_dialogues", {
    name = "sAdmin: can edit Talksmith",
    description = "Uses Talksmith's server-side privilege policy.",
    params = {},
    run = function(context)
        return TS.Permissions.Has(context.player, "talksmith.editor.open")
    end,
})

TS.Providers.Register("permissions", ID, {
    integration = ID,
    priority = 110,
    has_access = function(_, player, access)
        if not isstring(access) or #access > 128 then
            return false
        end
        local allowed = sAdmin.hasPermission(player, access)
        return allowed ~= nil and allowed ~= false
    end,
    get_group = function(_, player)
        return player:GetUserGroup()
    end,
})

TS.Integrations.RegisterVariable("sadmin.usergroup", {
    integration = ID,
    resolve = function(context)
        return context.player:GetUserGroup()
    end,
})
