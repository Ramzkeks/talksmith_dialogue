local TS = Talksmith

local function translatedName(value)
    value = tostring(value or "")
    local key = string.sub(value, 1, 1) == "#" and string.sub(value, 2) or value
    return language.GetPhrase(key)
end

function TS.Editor.ClassPickerItems(kind, params)
    local catalog = TS.Editor.Catalog and TS.Editor.Catalog.class_pickers or {}
    local sources = catalog[kind] or {}
    if kind == "vj_weapon" then
        sources = {}
        for _, npc in ipairs(catalog.vj_npc or {}) do
            if npc.id == (params or {}).class then
                sources = npc.weapons or {}
                break
            end
        end
    end
    local items, seen = {}, {}
    for _, source in ipairs(sources) do
        if isstring(source.id) and not seen[source.id] then
            seen[source.id] = true
            items[#items + 1] = {
                id = source.id,
                name = translatedName(source.name or source.id),
                group = isstring(source.group) and source.group ~= "" and source.group or TS.L("class_picker_classes"),
            }
        end
    end
    return items
end

function TS.Editor.OpenClassPicker(kind, params, current, onSelect)
    return TS.Editor.OpenReferencePicker({
        title = TS.L((kind == "npc" or kind == "vj_npc") and "class_picker_npcs" or "class_picker_weapons"),
        placeholder = TS.L("class_picker_search"),
        emptyText = TS.L(kind == "vj_weapon" and "class_picker_no_npc_weapons" or "class_picker_empty"),
        current = current,
        items = TS.Editor.ClassPickerItems(kind, params),
        copyable = true,
        onSelect = onSelect,
    })
end

-- Settings responses carry the current server allowlist, including edits made
-- while Studio is open. Preserve names where possible; class IDs always work.
function TS.Editor.UpdateAllowedWeaponChoices(classes)
    if not TS.Editor.Catalog or not istable(classes) then return end
    local catalog = TS.Editor.Catalog.class_pickers or {}
    TS.Editor.Catalog.class_pickers = catalog
    local known = {}
    for _, item in ipairs(catalog.weapon or {}) do known[item.id] = item end
    for _, definition in pairs(list.Get("Weapon") or {}) do
        if istable(definition) and isstring(definition.ClassName) then
            known[definition.ClassName] = {
                id = definition.ClassName, name = definition.PrintName or definition.ClassName,
                group = definition.Category or "",
            }
        end
    end
    catalog.weapon = {}
    for _, class in ipairs(classes) do
        catalog.weapon[#catalog.weapon + 1] = known[class] or { id = class, name = class, group = "" }
    end
end
