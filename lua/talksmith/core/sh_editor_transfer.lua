local TS = Talksmith
-- Editor-only transport. Saved documents and the runtime protocol are unchanged.
local CHUNK = 48000
local TIMEOUT = 30
local MESSAGE, ACK = "ts_editor_chunk", "ts_editor_chunk_ack"
local kinds = { catalog = 1, list = 2, document = 3, export = 4, save = 5 }
local incoming, outgoing = {}, {}
local serial = 0
TS.Editor.Transfer = { Handlers = {}, ListLimit = 8388608 }
local T = TS.Editor.Transfer

local function limit(kind)
    if kind == kinds.catalog then return 2097152 end
    if kind == kinds.list then return T.ListLimit end
    return TS.Config.max_document_bytes
end

local function peerKey(p)
    return SERVER and p or "server"
end

local function send(p)
    if SERVER then net.Send(p) else net.SendToServer() end
end

local function report(reason)
    if SERVER then
        TS.Logging.Log(0, "Editor transfer: " .. reason)
    else
        TS.Runtime.Notify(TS.L("save_failed", reason), NOTIFY_ERROR, 5)
    end
end

function T.Decode(raw, maximum)
    if not raw or #raw > maximum then return end
    -- The byte limit is enforced before parsing; large graphs exceed 15,000 keys.
    local ok, value = pcall(util.JSONToTable, raw, true, true)
    if ok and istable(value) then return value end
end

local function writeChunk(p, kind, state)
    local part = state.raw:sub(state.offset + 1, state.offset + CHUNK)
    state.nextOffset = state.offset + #part
    state.expires = RealTime() + TIMEOUT
    net.Start(MESSAGE)
    net.WriteUInt(kind, 3)
    net.WriteUInt(state.id, 32)
    net.WriteUInt(#state.raw, 32)
    net.WriteUInt(state.offset, 32)
    net.WriteUInt(state.extra, 32)
    net.WriteUInt(#part, 16)
    net.WriteData(part, #part)
    send(p)
end

function T.Send(name, raw, p, extra)
    local kind = kinds[name]
    if not kind or not raw or #raw == 0 or #raw > limit(kind) + 1024 then
        report("too_large")
        return false
    end
    local key = peerKey(p)
    outgoing[key] = outgoing[key] or {}
    serial = serial % 4294967295 + 1
    local state = { id = serial, raw = raw, offset = 0, extra = extra or 0 }
    outgoing[key][kind] = state
    writeChunk(p, kind, state)
    return true
end

function T.Cancel(name, p)
    local group = outgoing[peerKey(p)]
    if group then group[kinds[name]] = nil end
end

if SERVER then
    util.AddNetworkString(MESSAGE)
    util.AddNetworkString(ACK)
end

net.Receive(ACK, function(len, p)
    if len ~= 67 then return end
    local kind, id, offset = net.ReadUInt(3), net.ReadUInt(32), net.ReadUInt(32)
    local group = outgoing[peerKey(p)]
    local state = group and group[kind]
    if not state or state.id ~= id or state.nextOffset ~= offset then return end
    if offset == #state.raw then
        group[kind] = nil
        return
    end
    state.offset = offset
    -- Only one chunk per transfer is in flight; ACKs prevent net buffer overflow.
    writeChunk(p, kind, state)
end)

net.Receive(MESSAGE, function(len, p)
    if len < 147 or len > CHUNK * 8 + 147 then return end
    local kind = net.ReadUInt(3)
    if kind < 1 or kind > 5 then return end
    if SERVER then
        if kind ~= kinds.save or not TS.Permissions.CanUseEditor(p) then return end
    elseif kind == kinds.save then
        return
    end
    local id, total = net.ReadUInt(32), net.ReadUInt(32)
    local offset, extra, size = net.ReadUInt(32), net.ReadUInt(32), net.ReadUInt(16)
    if total <= 0 or total > limit(kind) + 1024 or size <= 0 or size > CHUNK
        or offset + size > total or len ~= 147 + size * 8 then return end
    local key = peerKey(p)
    incoming[key] = incoming[key] or {}
    local group = incoming[key]
    local state = group[kind]
    if offset == 0 then
        if SERVER and not TS.Network.Allow(p, "save", 1) then return end
        state = { id = id, total = total, extra = extra, offset = 0, parts = {} }
        group[kind] = state
    end
    if not state or state.id ~= id or state.total ~= total or state.extra ~= extra
        or state.offset ~= offset then return end
    local part = net.ReadData(size)
    if not part or #part ~= size then group[kind] = nil return end
    state.parts[#state.parts + 1] = part
    state.offset = offset + size
    state.expires = RealTime() + TIMEOUT
    net.Start(ACK)
    net.WriteUInt(kind, 3)
    net.WriteUInt(id, 32)
    net.WriteUInt(state.offset, 32)
    send(p)
    if state.offset ~= total then return end
    group[kind] = nil
    local raw = util.Decompress(table.concat(state.parts), limit(kind))
    if not raw or #raw > limit(kind) then report("invalid") return end
    for name, code in pairs(kinds) do
        if kind == code and T.Handlers[name] then
            T.Handlers[name](raw, p, extra)
            return
        end
    end
end)

timer.Create("Talksmith.EditorTransferCleanup", 5, 0, function()
    for _, transfers in ipairs({ incoming, outgoing }) do
        for key, group in pairs(transfers) do
            if SERVER and not IsValid(key) then
                transfers[key] = nil
            else
                for kind, state in pairs(group) do
                    if state.expires and state.expires < RealTime() then
                        group[kind] = nil
                        report("transfer_timeout")
                    end
                end
                if next(group) == nil then transfers[key] = nil end
            end
        end
    end
end)
