local TS = Talksmith
local ID = "ulx"

TS.Integrations.Register(ID, {
    name = "ULX",
    category = "permissions",
    priority = 90,
    capabilities = { "permissions", "CAMI", "admin-mod" },
    detect = function()
        if not istable(ULib) or not istable(ULib.ucl) or not isfunction(ULib.ucl.query) then
            return false, "ULib dependency is unavailable"
        end

        return istable(ulx), "ULX API"
    end,
})

TS.Integrations.RegisterCondition(ID, "has_access", {
    name = "ULX: has command access",
    params = { access = { type = "string", required = true, max = 128 } },
    run = function(context, params)
        return ULib.ucl.query(context.player, params.access) == true
    end,
})
TS.Integrations.RegisterCondition(ID, "can_edit_dialogues", {
    name = "ULX: can edit Talksmith",
    description = "Uses Talksmith's server-side privilege policy.",
    params = {},
    run = function(context)
        return TS.Permissions.Has(context.player, "talksmith.editor.open")
    end,
})
