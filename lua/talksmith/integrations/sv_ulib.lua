local TS = Talksmith
local ID = "ulib"

TS.Integrations.Register(ID, {
    name = "ULib",
    category = "permissions",
    priority = 100,
    capabilities = { "permissions", "usergroups", "CAMI" },
    detect = function()
        return istable(ULib) and istable(ULib.ucl) and isfunction(ULib.ucl.query), "ULib UCL API"
    end,
})

TS.Integrations.RegisterCondition(ID, "has_access", {
    name = "ULib: has access",
    params = { access = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        return ULib.ucl.query(context.player, params.access) == true
    end,
})
TS.Integrations.RegisterCondition(ID, "usergroup_is", {
    name = "ULib: usergroup is",
    params = { group = { type = "string", required = true, max = 64 } },
    run = function(context, params)
        return string.lower(context.player:GetUserGroup()) == string.lower(params.group)
    end,
})
TS.Providers.Register("permissions", ID, {
    integration = ID,
    priority = 100,
    has_access = function(_, player, access)
        return ULib.ucl.query(player, access) == true
    end,
    get_group = function(_, player)
        return player:GetUserGroup()
    end,
})

TS.Integrations.RegisterVariable("ulib.usergroup", {
    integration = ID,
    resolve = function(context)
        return context.player:GetUserGroup()
    end,
})
