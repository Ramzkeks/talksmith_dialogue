local TS = Talksmith
local MAX_ITEMS, MAX_TEXT_BYTES, MAX_TOTAL_BYTES = 32, 65536, 262144

-- Text history is client-local and lasts for this game session. Never mix it
-- with Editor.Clipboard, which contains copied graph nodes.
TS.Editor.TextClipboard = TS.Editor.TextClipboard or {}

function TS.Editor.RememberCopiedText(value)
    if not isstring(value) or value == "" or #value > MAX_TEXT_BYTES then return false end
    local history = TS.Editor.TextClipboard
    for index = #history, 1, -1 do
        if history[index] == value then table.remove(history, index) end
    end
    table.insert(history, 1, value)
    local bytes = 0
    for index = #history, 1, -1 do
        if index > MAX_ITEMS then table.remove(history, index) end
    end
    for index, text in ipairs(history) do
        bytes = bytes + #text
        if bytes > MAX_TOTAL_BYTES then
            for remove = #history, index, -1 do table.remove(history, remove) end
            break
        end
    end
    hook.Run("Talksmith.TextClipboardChanged")
    return true
end

function TS.Editor.ClearTextClipboard()
    TS.Editor.TextClipboard = {}
    hook.Run("Talksmith.TextClipboardChanged")
end

-- Spawnmenu's Copy to clipboard and addon export buttons use this API. Keep
-- its native behavior/return value and install only once across Lua reloads.
if not TS.Editor.NativeSetClipboardText then
    TS.Editor.NativeSetClipboardText = SetClipboardText
    SetClipboardText = function(value)
        local result = TS.Editor.NativeSetClipboardText(value)
        TS.Editor.RememberCopiedText(value)
        return result
    end
end

function TS.Editor.SelectedEntryText(entry)
    local first, last = entry:GetSelectedTextRange()
    first, last = math.min(first, last), math.max(first, last)
    if first == last then return "" end
    return utf8.sub(entry:GetText(), first + 1, last)
end

function TS.Editor.TrackClipboardEntry(entry)
    if entry._talksmithClipboardTracked then return end
    entry._talksmithClipboardTracked = true
    local base = entry.OnKeyCodeTyped
    entry.OnKeyCodeTyped = function(self, key)
        if (key == KEY_C or key == KEY_X)
            and (input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)) then
            TS.Editor.RememberCopiedText(TS.Editor.SelectedEntryText(self))
        end
        if base then return base(self, key) end
    end
end

function TS.Editor.OpenTextClipboard(onSelect)
    local screen = TS.Editor.OpenReferencePicker({
        title = TS.L("text_clipboard"),
        placeholder = TS.L("text_clipboard_search"),
        emptyText = TS.L("text_clipboard_empty"),
        hideIDs = true,
        preserveOrder = true,
        items = function()
            local items = {}
            for _, value in ipairs(TS.Editor.TextClipboard) do
                items[#items + 1] = { id = value, name = value, group = TS.L("text_clipboard_recent") }
            end
            return items
        end,
        onSelect = function(value)
            SetClipboardText(value)
            if onSelect then onSelect(value)
            else TS.Runtime.Notify(TS.L("text_clipboard_copied"), NOTIFY_GENERIC, 2) end
        end,
        buildFooter = function(footer, picker)
            footer:SetTall(146)
            footer:DockMargin(0, 10, 8, 0)
            local hint = footer:Add("DLabel")
            hint:Dock(TOP)
            hint:SetTall(38)
            hint:SetWrap(true)
            hint:SetFont("Talksmith_E_Small")
            hint:SetTextColor(TS.Editor.Theme.muted)
            hint:SetText(TS.L("text_clipboard_hint"))

            local actions = footer:Add("DPanel")
            actions:Dock(BOTTOM)
            actions:SetTall(30)
            actions:DockMargin(0, 6, 0, 0)
            actions.Paint = function() end
            local clear = actions:Add("DButton")
            clear:Dock(RIGHT)
            clear:SetWide(110)
            TS.Editor.StyleButton(clear, { label = TS.L("text_clipboard_clear"), quiet = true, icon = "trash" })
            clear.DoClick = TS.Editor.ClearTextClipboard
            local add = actions:Add("DButton")
            add:Dock(LEFT)
            add:SetWide(130)
            TS.Editor.StyleButton(add, { label = TS.L("text_clipboard_add"), accent = true, icon = "plus" })

            local entry = footer:Add("DTextEntry")
            entry:Dock(FILL)
            entry:SetMultiline(true)
            entry:SetUpdateOnType(true)
            entry:SetPlaceholderText(TS.L("text_clipboard_paste"))
            TS.Editor.StyleEntry(entry)
            add.DoClick = function()
                if TS.Editor.RememberCopiedText(entry:GetText()) then
                    entry:SetText("")
                else
                    TS.Runtime.Notify(TS.L("text_clipboard_invalid"), NOTIFY_ERROR, 3)
                end
            end
        end,
    })
    TS.Editor.TextClipboardPicker = screen
    return screen
end

hook.Add("Talksmith.TextClipboardChanged", "Talksmith.RefreshTextClipboard", function()
    local picker = TS.Editor.TextClipboardPicker
    if IsValid(picker) then picker:RefreshItems() end
end)
