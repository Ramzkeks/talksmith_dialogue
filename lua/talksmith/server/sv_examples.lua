local TS = Talksmith
local MAX_NET_PAYLOAD = 60000

util.AddNetworkString("ts_editor_example")

local function sendFailure(player, key, code)
    net.Start("ts_editor_example")
    net.WriteBool(false)
    net.WriteString(key or "")
    net.WriteString(code or "load_failed")
    net.Send(player)
end

local function uniqueDialogueID(base)
    base = TS.Utils.SafeID(base or "") or "talksmith_example"
    if not TS.Dialogues.Exists(base) then
        return base
    end

    for index = 2, 999 do
        local suffix = "_" .. index
        local candidate = string.sub(base, 1, 64 - #suffix) .. suffix
        if not TS.Dialogues.Exists(candidate) then
            return candidate
        end
    end
end

function TS.Examples.LoadDocument(exampleID, language, author)
    local entry = TS.Examples.Get(exampleID)
    local path = entry and TS.Examples.Path(entry, language)
    if not entry or not path then
        return nil, "not_found"
    end

    local raw = file.Read(path, "GAME")
    if not isstring(raw) or raw == "" then
        TS.Logging.Log(0, "Could not read Talksmith example " .. path)
        return nil, "not_found"
    end
    if #raw > TS.Config.max_document_bytes then
        return nil, "too_large"
    end

    local decoded, document = pcall(util.JSONToTable, raw, false, true)
    if not decoded or not istable(document) then
        TS.Logging.Log(0, "Could not decode Talksmith example " .. path)
        return nil, "invalid_json"
    end

    local id = uniqueDialogueID(document.id or entry.id)
    if not id then
        return nil, "id_exhausted"
    end

    document.id = id
    document.meta = istable(document.meta) and document.meta or {}
    document.meta.title = TS.Utils.ClampString(document.meta.title or TS.Examples.Text(entry, "title", language), 128)
    document.meta.author = TS.Utils.ClampString(author or "", 64)
    document.meta.created = os.time()
    document.meta.modified = document.meta.created
    document.meta.revision = 0

    if istable(document.settings)
        and not TS.Utils.InList(TS.Config.allowed_themes, document.settings.theme)
    then
        document.settings.theme = "default"
    end

    local checked, valid, issues = TS.Utils.SafeCall(
        "validate bundled Talksmith example",
        TS.Validation.ValidateDialogue,
        document
    )
    if not checked or not valid then
        local first = istable(issues) and issues[1]
        TS.Logging.Log(
            0,
            "Rejected bundled Talksmith example "
                .. path
                .. ": "
                .. tostring(first and first.message or "validation failed")
        )
        return nil, "invalid_document"
    end

    return document
end

net.Receive("ts_editor_example", function(length, player)
    if length > 2048
        or not TS.Network.Allow(player, "example", 0.35)
        or not TS.Permissions.CanUseEditor(player)
    then
        return
    end

    local key = net.ReadString()
    local language = net.ReadString() == "ru" and "ru" or "en"
    local document, reason = TS.Examples.LoadDocument(key, language, player:SteamID64())
    if not document then
        return sendFailure(player, key, reason)
    end

    local json = util.TableToJSON(document)
    if not json or #json > TS.Config.max_document_bytes then
        return sendFailure(player, key, "too_large")
    end
    local payload = util.Compress(json)
    if not payload or #payload > MAX_NET_PAYLOAD then
        return sendFailure(player, key, "too_large")
    end

    net.Start("ts_editor_example")
    net.WriteBool(true)
    net.WriteString(key)
    net.WriteUInt(#payload, 20)
    net.WriteData(payload, #payload)
    net.Send(player)
end)
