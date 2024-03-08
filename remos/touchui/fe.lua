--- FriendlyEvents
-- A CC event wrapper
-- Licensed under CC0

local expect = require("cc.expect").expect

-- CC Event Lookup Table
-- This should be tables of named indicies as a map from
-- {2, 3, 4, ...} to string name indices into the event table
local eventLUT = {
    -- base CC events
    alarm = { "id" },
    char = { "char" },
    computer_command = {},
    disk = { "side" },
    disk_eject = { "side" },
    http_check = { "url", "success", "err" },
    http_failure = { "url", "err", "handle" },
    http_success = { "url", "handle" },
    key = { "key", "is_held" },
    key_up = { "key" },
    modem_message = { "side", "channel", "replyChannel", "message", "distance" },
    monitor_resize = { "side" },
    monitor_touch = { "side", "x", "y" },
    mouse_click = { "button", "x", "y" },
    mouse_drag = { "button", "x", "y" },
    mouse_scroll = { "dir", "x", "y" },
    mouse_up = { "button", "x", "y" },
    paste = { "text" },
    peripheral = { "side" },
    peripheral_detach = { "side" },
    rednet_message = { "sender", "message", "protocol" },
    redstone = {},
    speaker_audio_empty = { "side" },
    task_complete = { "id", "success", "err" },
    term_resize = {},
    terminate = {},
    turtle_inventory = {},
    websocket_closed = { "url" },
    websocket_failure = { "url", "err" },
    websocket_message = { "url", "message", "binary" },
    websocket_success = { "url", "handle" },

    -- KTWSL https://github.com/MasonGulu/msks/blob/main/ktwsl.lua
    krist_transaction = { "to", "from", "value", "transaction" },
    krist_stop = { "err" },
}

--- Function that takes an event table, and applies the LUT to it
local function applyLUT(e, suppressErr)
    expect(1, e, "table")
    local LUT = eventLUT[e[1]]
    if LUT then
        for k, v in ipairs(LUT) do
            e[v] = e[k + 1]
        end
    elseif not suppressErr then
        error("Event " .. e[1] .. " not supported!")
    end
    e.event = e[1]
    return e
end

--- Function that checks if target is in t
local function isIn(target, t)
    for k, v in pairs(t) do
        if v == target then return true end
    end
    return false
end

---Add an event, specifying any event parameters
---@param eventName string
---@param ... string
local function addEvent(eventName, ...)
    eventLUT[eventName] = { ... }
end

--- Fancy pullEvent that takes a table of desired events
---@param filters string[]? table of desired events ie. {"mouse_click", "modem_message"}
---@param timeout number? time in seconds to return nil if no event matching the filter is recieved
---@param raw boolean? use pullEventRaw and catch "terminate" events
---@param suppressErr boolean? disable erroring upon recieving an unsupported event, just return the standard event table instead.
--
---@return table? event information
local function pullEvent(filters, timeout, raw, suppressErr)
    assert(not (timeout and isIn("timer", filters or {})), "Cannot set timeout when 'timer' is a targetted event.")
    local timerID, e
    if timeout then
        timerID = os.startTimer(timeout)
    end
    repeat
        if raw then
            e = { os.pullEventRaw() }
        else
            e = { os.pullEvent() }
        end
        if timeout then
            if e[1] == "timer" and e[2] == timerID then
                -- timed out
                return nil
            end
        end
    until not filters or isIn(e[1], filters)
    if timeout then
        os.cancelTimer(timerID)
    end
    return applyLUT(e, suppressErr)
end

return {
    pullEvent = pullEvent,
    addEvent = addEvent
}
