local TS = Talksmith

local rights = {
    "talksmith.editor.open",
    "talksmith.dialogues.create",
    "talksmith.dialogues.edit",
    "talksmith.dialogues.delete",
    "talksmith.dialogues.publish",
    "talksmith.actors.manage",
    "talksmith.settings.manage",
    "talksmith.integrations.manage",
    "talksmith.diagnostics.view",
    "talksmith.actions.dangerous",
    "talksmith.actions.economy",
    "talksmith.actions.inventory",
    "talksmith.actions.progression",
    "talksmith.actions.jobs",
    "talksmith.actions.events",
    "talksmith.wire.manage",
}

TS.Permissions.Rights = rights
TS.Config.permission_groups = table.Copy(istable(TS.Config.permission_groups) and TS.Config.permission_groups or {})

local knownRights = {}

for _, right in ipairs(rights) do
    knownRights[right] = true
end

local DEFAULT_GROUP = "superadmin"
local MAX_GROUP_LENGTH = 64
local MAX_GROUPS = 256

local function safeGroupName(group)
    if not isstring(group) then
        return nil
    end

    group = string.Trim(group)
    if group == "" or #group > MAX_GROUP_LENGTH or string.find(group, "%c") then
        return nil
    end

    return group
end

local function sameGroup(left, right)
    return isstring(left)
        and isstring(right)
        and string.lower(left) == string.lower(right)
end

local function findGroupKey(groups, wanted)
    if not istable(groups) or not isstring(wanted) then
        return nil
    end
    if groups[wanted] ~= nil then
        return wanted
    end

    for group in pairs(groups) do
        if isstring(group) and sameGroup(group, wanted) then
            return group
        end
    end
end

local function sAdminAvailable()
    return istable(sAdmin)
        and istable(sAdmin.usergroups)
        and isfunction(sAdmin.hasPermission)
end

local function ulxAvailable()
    return istable(ulx)
        and istable(ULib)
        and istable(ULib.ucl)
        and istable(ULib.ucl.groups)
end

function TS.Permissions.GetAdminBackend()
    if sAdminAvailable() then
        return "sadmin", "sAdmin"
    end
    if ulxAvailable() then
        return "ulx", "ULX"
    end
    return nil
end

function TS.Permissions.HasAdminBackend()
    return TS.Permissions.GetAdminBackend() ~= nil
end

local function sAdminGroupCatalog()
    local result = {}
    for group, data in pairs(sAdmin.usergroups or {}) do
        group = safeGroupName(group)
        if group then
            local permissions = istable(data) and data.permissions or nil
            result[#result + 1] = {
                id = group,
                weight = tonumber(permissions and permissions.immunity),
            }
        end
    end
    return result
end

local function ulxGroupWeight(group, groups)
    local current = group
    local visited = {}
    local depth = 0
    local base = 0

    for _ = 1, 32 do
        if not isstring(current) or visited[string.lower(current)] then
            break
        end
        visited[string.lower(current)] = true
        if sameGroup(current, "superadmin") then
            base = 3000
        elseif sameGroup(current, "admin") then
            base = math.max(base, 2000)
        elseif sameGroup(current, "user") then
            base = math.max(base, 1000)
        end

        local key = findGroupKey(groups, current)
        local data = key and groups[key] or nil
        local inherited = istable(data) and data.inherit_from or nil
        if not isstring(inherited) or sameGroup(inherited, current) then
            break
        end
        current = inherited
        depth = depth + 1
    end

    return base + depth
end

local function ulxGroupCatalog()
    local result = {}
    local groups = ULib.ucl.groups or {}
    for group in pairs(groups) do
        group = safeGroupName(group)
        if group then
            result[#result + 1] = {
                id = group,
                weight = ulxGroupWeight(group, groups),
            }
        end
    end
    return result
end

function TS.Permissions.GetGroupCatalog()
    local backend = TS.Permissions.GetAdminBackend()
    if not backend then
        return {}
    end

    local groups = backend == "sadmin" and sAdminGroupCatalog() or ulxGroupCatalog()
    local seen = {}
    local out = {}

    for _, entry in ipairs(groups) do
        local id = safeGroupName(entry.id)
        local key = id and string.lower(id) or nil
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = {
                id = id,
                name = id,
                weight = tonumber(entry.weight),
            }
        end
    end

    if not seen[DEFAULT_GROUP] then
        out[#out + 1] = {
            id = DEFAULT_GROUP,
            name = DEFAULT_GROUP,
            weight = 3000,
        }
    end

    table.sort(out, function(left, right)
        local leftWeight = tonumber(left.weight)
        local rightWeight = tonumber(right.weight)
        if leftWeight ~= nil and rightWeight ~= nil and leftWeight ~= rightWeight then
            return leftWeight < rightWeight
        end
        if leftWeight ~= nil and rightWeight == nil then
            return true
        end
        if leftWeight == nil and rightWeight ~= nil then
            return false
        end
        return string.lower(left.id) < string.lower(right.id)
    end)

    while #out > MAX_GROUPS do
        local removeIndex = #out
        if sameGroup(out[removeIndex].id, DEFAULT_GROUP) then
            removeIndex = removeIndex - 1
        end
        table.remove(out, removeIndex)
    end

    return out
end

function TS.Permissions.FindAvailableGroup(group)
    group = safeGroupName(group)
    if not group then
        return nil
    end

    local backend = TS.Permissions.GetAdminBackend()
    if not backend then
        return nil
    end

    local groups = backend == "sadmin" and sAdmin.usergroups or ULib.ucl.groups
    local key = findGroupKey(groups, group)
    if key then
        return key
    end
    if sameGroup(group, DEFAULT_GROUP) then
        return DEFAULT_GROUP
    end
end

function TS.Permissions.GetConfiguredGroup(right)
    if not knownRights[right] then
        return DEFAULT_GROUP
    end

    local configured = safeGroupName(TS.Config.permission_groups[right])
    if not TS.Permissions.HasAdminBackend() then
        return DEFAULT_GROUP
    end

    return TS.Permissions.FindAvailableGroup(configured or DEFAULT_GROUP) or DEFAULT_GROUP
end

function TS.Permissions.GetSettings()
    local settings = {}
    for _, right in ipairs(rights) do
        settings[right] = TS.Permissions.GetConfiguredGroup(right)
    end
    return settings
end

function TS.Permissions.SetConfiguredGroup(right, group)
    if not knownRights[right] or not TS.Permissions.HasAdminBackend() then
        return false, "permissions_unavailable"
    end

    group = TS.Permissions.FindAvailableGroup(group)
    if not group then
        return false, "invalid_group"
    end

    TS.Config.permission_groups[right] = group
    return true
end

local function ulxGroupHasMinimum(currentGroup, minimumGroup)
    local groups = ULib.ucl.groups or {}
    local current = findGroupKey(groups, currentGroup) or currentGroup
    local visited = {}

    for _ = 1, 32 do
        if not isstring(current) or visited[string.lower(current)] then
            return false
        end
        if sameGroup(current, minimumGroup) then
            return true
        end

        visited[string.lower(current)] = true
        local key = findGroupKey(groups, current)
        local data = key and groups[key] or nil
        local inherited = istable(data) and data.inherit_from or nil
        if not isstring(inherited) or sameGroup(inherited, current) then
            break
        end
        current = inherited
    end

    if CAMI and isfunction(CAMI.UsergroupInherits) then
        local ok, allowed = pcall(CAMI.UsergroupInherits, currentGroup, minimumGroup)
        return ok and allowed == true
    end

    return false
end

local function sAdminGroupHasMinimum(currentGroup, minimumGroup)
    local groups = sAdmin.usergroups or {}
    local currentKey = findGroupKey(groups, currentGroup)
    local minimumKey = findGroupKey(groups, minimumGroup)
    if not currentKey or not minimumKey then
        return sameGroup(currentGroup, minimumGroup)
    end
    if sameGroup(currentKey, minimumKey) then
        return true
    end

    local currentPermissions = istable(groups[currentKey]) and groups[currentKey].permissions or nil
    local minimumPermissions = istable(groups[minimumKey]) and groups[minimumKey].permissions or nil
    local currentImmunity = tonumber(currentPermissions and currentPermissions.immunity)
    local minimumImmunity = tonumber(minimumPermissions and minimumPermissions.immunity)
    return currentImmunity ~= nil
        and minimumImmunity ~= nil
        and currentImmunity >= minimumImmunity
end

function TS.Permissions.Has(player, right)
    if not IsValid(player) or not knownRights[right] then
        return false
    end

    if player:IsSuperAdmin() then
        return true
    end

    local backend = TS.Permissions.GetAdminBackend()
    if not backend then
        return false
    end

    local currentGroup = safeGroupName(player:GetUserGroup())
    local minimumGroup = TS.Permissions.GetConfiguredGroup(right)
    if not currentGroup or not minimumGroup then
        return false
    end

    if backend == "sadmin" then
        return sAdminGroupHasMinimum(currentGroup, minimumGroup)
    end
    return ulxGroupHasMinimum(currentGroup, minimumGroup)
end

function TS.Permissions.IsKnown(right)
    return knownRights[right] == true
end

function TS.Permissions.Invalidate(player, right)
end

function TS.Permissions.CanUseEditor(player, right)
    return TS.Config.editor_enabled == true
        and TS.Permissions.Has(player, "talksmith.editor.open")
        and (right == nil or TS.Permissions.Has(player, right))
end

local function requiredActionPermission(definition)
    if not istable(definition) then
        return "talksmith.actions.dangerous"
    end
    if isstring(definition.permission) and knownRights[definition.permission] then
        return definition.permission
    end
    if isstring(definition.permission) then
        return "talksmith.actions.dangerous"
    end
    if definition.dangerous == true then
        return "talksmith.actions.dangerous"
    end
    if definition.safe == true then
        return nil
    end
    return "talksmith.actions.dangerous"
end

function TS.Permissions.CanPublishDialogue(player, doc)
    if not TS.Permissions.Has(player, "talksmith.dialogues.publish") or not istable(doc) or not istable(doc.nodes) then
        return false, { "talksmith.dialogues.publish" }
    end

    local needed = {}
    local nodeLimit = math.Clamp(math.floor(tonumber(TS.Config.max_nodes) or 256), 1, 4096)
    local totalNodeLimit = nodeLimit * 8
    local actionLimit = math.Clamp(math.floor(tonumber(TS.Config.max_action_entries) or 16), 1, 64)
    local optionLimit = math.Clamp(math.floor(tonumber(TS.Config.max_options) or 6), 1, 7)
    local visitedCount = 0
    local visitedDocuments = {}

    local scanDocument
    local function scan(entries, depth)
        for index = 1, math.min(istable(entries) and #entries or 0, actionLimit) do
            local entry = entries[index]
            local definition = istable(entry) and TS.Actions.Registry[entry.id]
            local permission = requiredActionPermission(definition)
            if permission then
                needed[permission] = true
            end
            if istable(entry)
                and entry.id == "core.open_dialogue"
                and istable(entry.params)
                and isstring(entry.params.dialogue)
            then
                local target = TS.Dialogues.Get(entry.params.dialogue)
                if not target or depth >= 8 then
                    needed["talksmith.actions.dangerous"] = true
                else
                    scanDocument(target, depth + 1)
                end
            end
        end
    end

    scanDocument = function(document, depth)
        if not istable(document) or not istable(document.nodes) then return end
        local documentID = TS.Utils.SafeID(document.id or "")
        if documentID and visitedDocuments[documentID] then return end
        if documentID then visitedDocuments[documentID] = true end

        for _, node in pairs(document.nodes) do
            visitedCount = visitedCount + 1
            if visitedCount > totalNodeLimit then
                needed["talksmith.actions.dangerous"] = true
                return
            end
            if istable(node) then
                scan(node.actions, depth)
                for index = 1, math.min(istable(node.options) and #node.options or 0, optionLimit) do
                    local option = node.options[index]
                    if istable(option) then scan(option.actions, depth) end
                end
            end
        end
    end
    scanDocument(doc, 0)

    local denied = {}
    for right in pairs(needed) do
        if not TS.Permissions.Has(player, right) then
            denied[#denied + 1] = right
        end
    end
    table.sort(denied)
    return #denied == 0, denied
end

hook.Add("sA:OnSyncedRank", "Talksmith.sAdminGroupsChanged", function()
    hook.Run("Talksmith.AdminGroupsChanged", "sadmin")
end)

hook.Add("CAMI.OnUsergroupRegistered", "Talksmith.AdminGroupRegistered", function()
    hook.Run("Talksmith.AdminGroupsChanged", TS.Permissions.GetAdminBackend())
end)

hook.Add("CAMI.OnUsergroupUnregistered", "Talksmith.AdminGroupUnregistered", function()
    hook.Run("Talksmith.AdminGroupsChanged", TS.Permissions.GetAdminBackend())
end)
