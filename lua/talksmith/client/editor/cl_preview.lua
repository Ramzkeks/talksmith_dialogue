local TS = Talksmith

local function paramsToString(params)
    local parts = {}
    for k, v in SortedPairs(istable(params) and params or {}) do
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(parts, ", ")
end

local function announce(refs, prefix)
    for _, x in ipairs(refs or {}) do
        local def = TS.Actions.Get(x.id)
        local name = def and def.name or x.id
        TS.Runtime.Notify(
            ("[%s] %s (%s)"):format(TS.L("preview_action"), name, paramsToString(x.params)),
            NOTIFY_HINT,
            4
        )
    end
end

function TS.Editor.Preview(doc)
    local ok = TS.Editor.ProblemSummary(doc)
    if not ok then
        TS.Runtime.Notify(TS.L("fix_errors"), NOTIFY_ERROR, 4)
        return
    end
    local starts = {}
    for _, candidate in ipairs(doc.settings.start_random or {}) do
        if isstring(candidate) and doc.nodes[candidate] then
            starts[#starts + 1] = candidate
        end
    end
    local id = #starts > 0 and starts[math.random(#starts)] or doc.start
    local function show()
        local node = doc.nodes[id]
        if not node then
            TS.Runtime.Close(false)
            return
        end
        announce(node.actions)
        local opts = {}
        for _, o in ipairs(node.options) do
            local flag = #(o.conditions or {}) > 0 and "  ⚑" or ""
            opts[#opts + 1] = o.text .. flag
        end
        TS.Runtime.Show({
            token = "preview",
            name = doc.settings.actor_name or "",
            subtitle = doc.settings.actor_subtitle or "",
            text = node.text or "",
            sound = node.sound or "",
            theme = doc.settings.theme or "default",
            options = opts,
            previewChoose = function(index)
                local o = node.options[index]
                if not o then
                    return
                end
                if #(o.conditions or {}) > 0 then
                    TS.Runtime.Notify("⚑ " .. TS.L("preview_conditions"), NOTIFY_HINT, 3)
                end
                announce(o.actions)
                local targets = {}
                for _, target in ipairs(o.next_random or {}) do
                    if doc.nodes[target] then
                        targets[#targets + 1] = target
                    end
                end
                local nextNode = #targets > 0 and targets[math.random(#targets)] or o.next
                if nextNode and doc.nodes[nextNode] then
                    id = nextNode
                    show()
                else
                    TS.Runtime.Close(false)
                    TS.Runtime.Notify(TS.L("preview_finished"), NOTIFY_GENERIC, 3)
                end
            end,
        })
    end
    show()
    TS.Runtime.Notify(TS.L("preview_hint"), NOTIFY_HINT, 4)
end
