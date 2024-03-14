package.path = package.path .. ";/libs/?.lua/;/libs/?/init.lua"

local termW, termH = term.getSize()
local draw = require "draw"

---@class Process
---@field pid integer
---@field ppid integer
---@field coro thread
---@field filter string?
---@field window Window?
---@field title string
---@field args any[]?
---@field x integer where on screen this process is located, for adjusting mouse events
---@field y integer where on screen this process is located, for adjusting mouse events
---@field focused boolean? whether this process should recieve mouse/keyboard events
---@field app boolean?
---@field recievedMouseClick boolean?
---@field terminateOnFocusLoss boolean?
---@field totalExeTime integer ms total resumed time
---@field lastExeTime integer ms last coroutine.resume took
---@field meanExeTime number ms average time / coroutine.resume
---@field cyclesAlive integer # of cycles this process has survived
---@field state "alive"|"dead"|"errored"|"terminated"
---@field children integer[]

local lastpid = 0
---@type table<integer,Process>
local processes = {}
---@type Process[] processes w/ windows, used for "alt tabbing"
local apps = {}
local focusedpid
local runningpid = 0

local menupid, homepid

settings.define("remos.autoCleanupOnFocusLoss", {
    description = "Whether dead apps should be cleaned up whenever focus is lost.",
    type = "boolean",
    default = true
})
---Whether a dead app should be cleaned up whenever focus is lost
local autoCleanupOnFocusLoss = settings.get("remos.autoCleanupOnFocusLoss")
settings.define("remos.autoCloseDeadApps", {
    description = "Whether all dead apps should be automatically closed.",
    type = "boolean",
    default = true
})
---Whether all apps should be automatically closed
local autoCloseDeadApps = settings.get("remos.autoCloseDeadApps")
settings.save()

local function logError(s, ...)
    local f = assert(fs.open("errors.txt", "a"))
    f.writeLine(s:format(...))
    f.close()
end

---Create a new process
---@param fun function
---@param title string
---@param window Window?
---@param ppid integer
---@return integer pid
local function addProcess(fun, title, ppid, window)
    lastpid = lastpid + 1
    local x, y = 1, 1
    if window then
        x, y = window.getPosition()
    end
    processes[lastpid] = {
        pid = lastpid,
        ppid = ppid,
        coro = coroutine.create(fun),
        window = window,
        title = title,
        x = x,
        y = y,
        focused = false,
        state = "alive",
        totalExeTime = 0,
        lastExeTime = 0,
        cyclesAlive = 0,
        meanExeTime = 0,
        children = {}
    }
    local parent = processes[ppid]
    if parent then
        parent.children[#parent.children + 1] = lastpid
    end
    return lastpid
end
local applicationWin = window.create(term.current(), 1, 2, termW, termH - 2)

---Explicitly create a new app process
---@param fun function
---@param title string
---@param ppid integer
---@return integer pid
local function addApp(fun, title, ppid)
    local w, h = applicationWin.getSize()
    local win = window.create(applicationWin, 1, 1, w, h, false)
    local pid = addProcess(fun, title, ppid, win)
    apps[#apps + 1] = processes[pid]
    processes[pid].x, processes[pid].y = 1, 2
    processes[pid].app = true
    return pid
end

local focusedEventLUT = {
    "mouse_click",
    "mouse_up",
    "mouse_drag",
    "key",
    "char",
    "mouse_scroll",
    "key_up",
    "backButton",
}
for k, v in ipairs(focusedEventLUT) do focusedEventLUT[v] = true end
---Tell if an event requires the process being focused
---@param e any[]
---@return boolean
local function isFocusedEvent(e)
    return not not focusedEventLUT[e[1]]
end

local mouseEventLUT = {
    "mouse_click",
    "mouse_up",
    "mouse_scroll",
    "mouse_drag"
}
for k, v in ipairs(mouseEventLUT) do mouseEventLUT[v] = true end

---@param e any[]
---@param process Process
local function offsetMouse(process, e)
    local t = table.pack(table.unpack(e, 1, e.n))
    if mouseEventLUT[t[1]] then
        t[3] = t[3] - process.x + 1
        t[4] = t[4] - process.y + 1
    end
    if e[1] == "mouse_click" then
        process.recievedMouseClick = true
    elseif e[1] == "mouse_up" then
        process.recievedMouseClick = false
    end
    return table.unpack(t, 1, t.n)
end

---Determine whether a given process has received the mouse_click event
---If they haven't, then they should not be sent
---@param e any[]
---@param process Process
local function shouldRecieveEvent(e, process)
    local focused = isFocusedEvent(e)
    local matchesFilter = process.filter == nil or e[1] == process.filter or e[1] == "terminate"
    if (focused and process.focused) or not focused then
        if e[1] == "mouse_click" or e[1] == "mouse_scroll" then
            return matchesFilter
        elseif mouseEventLUT[e[1]] then
            return process.recievedMouseClick and matchesFilter
        end
        return matchesFilter
    end
    return false
end

---Remove an element from an array
---@generic T:any
---@param t T[]
---@param v T
---@return boolean success
local function removeFromArray(t, v)
    for i, v2 in pairs(t) do
        if v == v2 then
            table.remove(t, i)
            return true
        end
    end
    return false
end

local focusedx, focusedy = 1, 1
local focusedfg, focusedbg = colors.white, colors.black
local cursorBlink = false

local terminateProcess
local function terminateProcessChildren(pid)
    if not processes[pid] then
        return
    end
    for _, cpid in ipairs(processes[pid].children) do
        terminateProcess(cpid)
    end
end

local bottombarpid, topbarpid
---@param process Process
local function updateProcessWindow(process)
    if process.window then
        local x, y, w, h = 1, 1, applicationWin.getSize()
        if process.pid == topbarpid then
            x, y = 1, 1
            w, h = termW, 1
        elseif process.pid == bottombarpid then
            x, y = 1, termH
            w, h = termW, 1
        end
        process.x, process.y = x, y
        process.window.reposition(x, y, w, h)
    end
end

local function updateApplicationWindow()
    termW, termH = term.getSize()
    applicationWin.reposition(1, 2, termW, termH - 2)
end

local popup, setFocused, cleanupProcess
---Resume a given process with given arguments, doesn't check filter
---@param process Process
---@param ... any
---@return any
local function resumeProcess(process, ...)
    _G.remos.pid = process.pid
    _G.remos.ppid = process.ppid
    local oldWin
    if process.window then
        oldWin = term.redirect(process.window)
    end
    runningpid = process.pid
    local startTime = os.epoch("utc")
    local ok, err = coroutine.resume(process.coro, ...)
    process.cyclesAlive = process.cyclesAlive + 1
    process.lastExeTime = os.epoch("utc") - startTime
    process.totalExeTime = process.totalExeTime + process.lastExeTime
    process.meanExeTime = process.totalExeTime / process.cyclesAlive
    runningpid = 0 -- Kernel running
    local e = { ... }
    if e[1] == "terminate" then
        process.state = "terminated"
    elseif not ok then
        process.state = "errored"
        local t = debug.traceback(process.coro, err)
        logError(t)
        if oldWin then
            term.redirect(oldWin)
        end
        term.setCursorPos(1, 1)
        process.terminateOnFocusLoss = autoCleanupOnFocusLoss
        popup(("%s errored!"):format(process.title), t)
    end
    process.filter = err
    if focusedpid == process.pid then
        focusedx, focusedy = process.window.getCursorPos()
        cursorBlink = process.window.getCursorBlink()
        focusedfg, focusedbg = draw.get_col(process.window)
    end
    if oldWin then
        term.redirect(oldWin)
    end
    if coroutine.status(process.coro) == "dead" then
        -- normal exit
        if process.state == "alive" then
            process.state = "dead"
        end
        draw.set_col(colors.white, colors.red, process.window)
        draw.center_text(1, ("** %s **"):format(process.state), process.window)
        process.terminateOnFocusLoss = autoCleanupOnFocusLoss
        terminateProcessChildren(process.pid)
        if autoCloseDeadApps then
            cleanupProcess(process.pid)
        end
    end
    return err
end

---Terminate a process
---@param pid integer
function terminateProcess(pid)
    local process = processes[pid]
    if process and process.state == "alive" then
        resumeProcess(process, "terminate")
    end
    terminateProcessChildren(pid)
end

---Cleanup the information associated with a given process
---@param pid integer
function cleanupProcess(pid)
    local process = processes[pid]
    if process then
        terminateProcess(pid)
        processes[pid] = nil
        if process.app then
            removeFromArray(apps, process)
            if focusedpid == process.pid then
                setFocused(menupid)
            end
        end
    end
end

local function clearFocused()
    local process = processes[focusedpid]
    if focusedpid and process then
        process.focused = nil
        local win = process.window
        if win then
            win.setVisible(false)
        end
        focusedpid = nil
        if process.terminateOnFocusLoss then
            cleanupProcess(process.pid)
        end
    end
    focusedpid = nil
end

---Set a process as the focused process
---@param pid integer?
function setFocused(pid)
    if not pid then
        clearFocused()
    end
    if pid and processes[pid] then
        local process = processes[pid]
        if process.app then
            clearFocused()
            focusedpid = pid
            if removeFromArray(apps, process) then
                -- put at top of recently used list
                table.insert(apps, 1, process)
            end
        end
        process.focused = true
        local win = process.window
        if win then
            win.setVisible(true)
            -- win.redraw()
        end
    end
end

---Tick a given process
---@param e any[]
---@param process Process
local function tickProcess(e, process)
    if e[1] == "term_resize" then
        updateProcessWindow(process)
    end
    if process.state ~= "alive" then
        -- if process.state == "dead" then
        --     -- this process died naturally
        --     cleanupProcess(process.pid)
        -- end
        return
    end
    if shouldRecieveEvent(e, process) then
        local err = resumeProcess(process, offsetMouse(process, e))
        process.filter = err
    end
    if process.pid == menupid and #apps == 0 then
        setFocused(homepid) -- if there are no apps open, redirect to home
    end
end

local function runProcesses()
    while true do
        local e = table.pack(os.pullEventRaw())
        if e[1] == "terminate" then
            -- TODO
        elseif e[1] == "backButton" and focusedpid == menupid then
            setFocused(homepid)
        elseif e[1] == "menuButton" and focusedpid == menupid then
            setFocused(homepid)
        else
            if e[1] == "term_resize" then
                updateApplicationWindow()
            end
            for pid, process in pairs(processes) do
                tickProcess(e, process)
            end
            term.setCursorPos(focusedx, focusedy + 1)
            term.setCursorBlink(cursorBlink)
            draw.set_col(focusedfg, focusedbg, term --[[@as Window]])
        end
    end
end

---@param fn string
---@param ppid integer
---@return integer?
---@return string?
local addAppFile = function(fn, ppid, ...)
    local func, err = loadfile(fn, "t", setmetatable({}, { __index = _ENV }))
    if not func then
        return nil, err
    end
    local id = addApp(func, fn, ppid)
    resumeProcess(processes[id], ...)
    setFocused(id)
    return id
end

---Create a new foreground process by running a file
---@param fn string
---@return integer?
---@return string?
local curAddAppFile = function(fn, ...)
    return addAppFile(fn, runningpid, ...)
end

---Show a popup
---@param title string
---@param body string
---@return integer? pid
function popup(title, body)
    local pid = addAppFile("remos/popup.lua", runningpid, title, body)
    return pid
end

---Set the title of a process
---@param pid integer
---@param title string
local function setProcessTitle(pid, title)
    processes[pid].title = title
end

---Set a program to terminate when it looses focus
---@param pid integer
local function terminateOnFocusLoss(pid)
    if not processes[pid] then
        return
    end
    processes[pid].terminateOnFocusLoss = true
end

--- required
_G.remos = {
    ---Create a new background process
    ---@param fn function
    ---@param title string
    ---@param win Window?
    ---@return integer pid
    addProcess = function(fn, title, win)
        return addProcess(fn, title, runningpid, win)
    end,
    ---Create a new foreground process
    ---@param fn function
    ---@param title string
    ---@return integer pid
    addApp = function(fn, title)
        return addApp(fn, title, runningpid)
    end,
    addAppFile = curAddAppFile,
    setFocused = setFocused,
    cleanupProcess = cleanupProcess,
    removeFromTable = removeFromArray,
    terminateProcess = terminateProcess,
    popup = popup,
    _apps = apps,
    _processes = processes,
    pid = 0, -- variables to get information about the current process
    ppid = 0,
    ---Set the title of the current process
    ---@param title string
    setTitle = function(title)
        setProcessTitle(runningpid, title)
    end,
    terminateOnFocusLoss = function()
        terminateOnFocusLoss(runningpid)
    end,
    ---Set the pid of the which process is "home"
    ---@param pid integer
    setHomePid = function(pid)
        removeFromArray(apps, processes[pid])
        homepid = pid
    end,
    ---Set the pid of the which process is "menu"
    ---@param pid integer
    setMenuPid = function(pid)
        removeFromArray(apps, processes[pid])
        menupid = pid
    end,
    ---Load a table from a file
    ---@param fn string
    ---@return table?
    ---@return string?
    loadTable = function(fn)
        local f, err = fs.open(fn, "r")
        if not f then
            return nil, err
        end
        local t = f.readAll()
        if not t then
            return nil, "Empty file"
        end
        f.close()
        return textutils.unserialise(t) --[[@as table?]], "Failed to unserialize"
    end,
    deepClone = function(t)
        local nt = {}
        for k, v in pairs(t) do
            if type(v) == "table" then
                nt[k] = remos.deepClone(v)
            else
                nt[k] = v
            end
        end
        return nt
    end,
    setTopBarPid = function(pid)
        topbarpid = pid
    end,
    setBottomBarPid = function(pid)
        bottombarpid = pid
    end
}

addProcess(assert(loadfile("remos/init.lua", "t", _ENV)), "INIT", 0)

os.queueEvent("REMOS BOOT")
runProcesses()
error("Kernel Exited!")
