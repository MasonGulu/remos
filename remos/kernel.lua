package.path = package.path .. ";/libs/?.lua/;/libs/?/init.lua"

if remos then
    error("Remos is already running!")
end

local expect = require("cc.expect").expect
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
---@field file string Original file this process was started from, inherits from parent if function
---@field recievedMouseClick boolean?
---@field terminateOnFocusLoss boolean?
---@field totalExeTime integer ms total resumed time
---@field lastExeTime integer ms last coroutine.resume took
---@field meanExeTime number ms average time / coroutine.resume
---@field maxExeTime number ms max time this process has taken
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

local menupid, homepid, notificationpid, initpid
local bottombarpid, topbarpid

---@class Notification
---@field title string
---@field content string
---@field pid integer
---@field icon string

---@type Notification[]
local notifications = {}
---@type {attached:"speaker"|"modem"|nil,usedBy:integer[],playing:string?,paused:boolean?}
local peripheralStatus = {
    usedBy = {}
}

local oldwrap = peripheral.wrap
local function updatePeripheral()
    if not pocket then
        return
    end
    os.queueEvent("remos_peripheral")
    local p = oldwrap("back")
    if not p then
        peripheralStatus.attached = nil
        return
    end
    peripheralStatus.attached = peripheral.getType(p) --[[@as "modem"|"speaker"]]
end
updatePeripheral()

local isRunning = true

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

settings.define("remos.timezone", {
    description = "Timezone offset from UTC",
    type = "number",
    default = 0
})

settings.define("remos.custom_palette_file", {
    description = "Custom palette to apply system-wide",
    type = "string"
})

settings.define("remos.splash_screen_delay", {
    description = "How long to show the Remos splash screen for",
    type = "number",
    default = 0.5
})

settings.define("remos.dark_mode", {
    description = "Dark mode",
    type = "boolean",
    default = false
})

settings.define("remos.invert_bar_colors", {
    description = "Invert the colors of the top/bottom bars",
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

---@param mesg string
local function panic(mesg)
    isRunning = false
    draw.set_col(colors.red, colors.white, term)
    term.clear()
    term.setCursorPos(1, 1)
    print("REMOS Kernel Panic")
    logError("Kernel Panic - %s", mesg)
    print(mesg)
    draw.set_col(colors.black, nil, term)
    print("[Enter] Enter CraftOS Shell")
    print("[Space] Reboot")
    while true do
        local _, k = os.pullEvent("key")
        if k == keys.space then
            os.reboot()
        elseif k == keys.enter then
            return
        end
    end
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
        maxExeTime = 0,
        children = {},
        file = processes[ppid].file
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
    "remos_back_button",
    "file_transfer"
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

local function mouseWithinAppSpace(x, y)
    return y < termH and y > 1
end

---Check if a process is critical
---@param pid integer
local function isCriticalProcess(pid)
    return pid == topbarpid or pid == bottombarpid or pid == menupid or pid == homepid or pid == notificationpid or
        pid == initpid
end

---Determine whether a given process has received the mouse_click event
---If they haven't, then they should not be sent
---@param e any[]
---@param process Process
local function shouldRecieveEvent(e, process)
    local focused = isFocusedEvent(e)
    local matchesFilter = process.filter == nil or e[1] == process.filter or e[1] == "terminate"
    if (focused and process.focused) or not focused then
        if e[1] == "terminate" then
            return focusedpid == process.pid and not isCriticalProcess(process.pid) -- only send to the focused app
        elseif e[1] == "mouse_click" or e[1] == "mouse_scroll" then
            return matchesFilter and (not process.app or mouseWithinAppSpace(e[3], e[4]))
        elseif mouseEventLUT[e[1]] then
            return process.recievedMouseClick and matchesFilter and (not process.app or mouseWithinAppSpace(e[3], e[4]))
        end
        return matchesFilter
    end
    return false
end

---Find an element in an array
---@generic T:any
---@param t T[]
---@param v T
---@return integer?
local function findInArray(t, v)
    for i, v2 in ipairs(t) do
        if v == v2 then
            return i
        end
    end
end

---Remove an element from an array
---@generic T:any
---@param t T[]
---@param v T
---@return boolean success
local function removeFromArray(t, v)
    expect(1, t, "table")
    local i = findInArray(t, v)
    if i then
        table.remove(t, i)
        return true
    end
    return false
end

local focusedx, focusedy = 1, 1
local focusedfg, focusedbg = colors.white, colors.black
local cursorBlink = false

local terminateProcess
---Terminate the children of a process
---@param pid number
local function terminateProcessChildren(pid)
    expect(1, pid, "number")
    if not processes[pid] then
        return
    end
    for _, cpid in ipairs(processes[pid].children) do
        terminateProcess(cpid)
    end
end

---@param process Process
local function updateProcessWindow(process)
    if process.window then
        local x, y, w, h = 1, 1, applicationWin.getSize()
        local systemProcess
        if process.pid == topbarpid then
            x, y = 1, 1
            w, h = termW, 1
            systemProcess = true
        elseif process.pid == bottombarpid then
            x, y = 1, termH
            w, h = termW, 1
            systemProcess = true
        end
        process.x, process.y = x, y
        if process.pid == bottombarpid then
            process.y = 1
        end
        process.window.reposition(x, y, w, h)
        if not systemProcess then
            process.y = 2
        end
    end
end

local function updateApplicationWindow()
    termW, termH = term.getSize()
    applicationWin.reposition(1, 2, termW, termH - 2)
end

settings.define("remos.use_nano_seconds", {
    description = "Use nanoseconds for statistics (CraftOS-PC)",
    type = "boolean",
    default = false
})

---@diagnostic disable-next-line: undefined-global
if not periphemu then
    settings.set("remos.use_nano_seconds", false)
end

local use_ns = settings.get("remos.use_nano_seconds")
local epoch_unit = use_ns and "nano" or "utc"


local function epoch()
    ---@diagnostic disable-next-line: param-type-mismatch
    return os.epoch(epoch_unit)
end

---@param process Process
---@param startTime integer
local function updateProcessStats(process, startTime)
    process.cyclesAlive = process.cyclesAlive + 1
    process.lastExeTime = epoch() - startTime
    process.totalExeTime = process.totalExeTime + process.lastExeTime
    process.meanExeTime = process.totalExeTime / process.cyclesAlive
    process.maxExeTime = math.max(process.maxExeTime, process.lastExeTime)
end

local kernelStartTime = epoch()

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
    updateProcessStats(processes[0], kernelStartTime)
    local startTime = epoch()
    local ok, err = coroutine.resume(process.coro, ...)
    runningpid = 0
    kernelStartTime = kernelStartTime + epoch() - startTime
    updateProcessStats(process, startTime)
    runningpid = 0 -- Kernel running
    local e = { ... }
    if not ok and e[1] ~= "terminate" then
        process.state = "errored"
        local t = debug.traceback(process.coro, err)
        logError("%s", t)
        if oldWin then
            term.redirect(oldWin)
        end
        if isCriticalProcess(process.pid) then
            -- System critical process errored
            panic("A critical system proccess has errored.\n" .. t)
            return
        end
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
        removeFromArray(peripheralStatus.usedBy, process.pid)
        updatePeripheral()
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
    expect(1, pid, "number")
    local process = processes[pid]
    if process and process.state == "alive" then
        resumeProcess(process, "terminate")
    end
    terminateProcessChildren(pid)
end

---Cleanup the information associated with a given process
---@param pid integer
function cleanupProcess(pid)
    expect(1, pid, "number")
    local process = processes[pid]
    if process then
        terminateProcess(pid)
        removeFromArray(peripheralStatus.usedBy, pid)
        updatePeripheral()
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
    expect(1, pid, "number", "nil")
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
    if process.pid == 0 then
        return -- Do not tick the KERNEL process
    end
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
        if not isRunning then
            return
        end
    end
    if focusedpid == menupid and #apps == 0 then
        setFocused(homepid) -- if there are no apps open, redirect to home
    end
end

local function runProcesses()
    isRunning = true
    while isRunning do
        updateProcessStats(processes[0], kernelStartTime)
        local e = table.pack(os.pullEventRaw())
        kernelStartTime = epoch()
        if e[1] == "remos_back_button" and focusedpid == menupid then
            setFocused(homepid)
        elseif e[1] == "remos_menu_button" and focusedpid == menupid then
            setFocused((apps[1] or { pid = homepid }).pid)
        else
            if e[1] == "term_resize" then
                updateApplicationWindow()
            end
            for pid, process in pairs(processes) do
                tickProcess(e, process)
                if not isRunning then return end
            end
            term.setCursorPos(focusedx, focusedy + 1)
            term.setCursorBlink(cursorBlink)
            draw.set_col(focusedfg, focusedbg, term)
        end
    end
end

---@param fn string
---@param ppid integer
---@param env table?
---@return integer?
---@return string?
local addAppFile = function(fn, ppid, env, ...)
    local func, err = loadfile(fn, "t", env or setmetatable({}, { __index = _ENV }))
    if not func then
        return nil, err
    end
    local id = addApp(func, fn, ppid)
    setFocused(id)
    processes[id].file = fn
    resumeProcess(processes[id], ...)
    return id
end

---Create a new foreground process by running a file
---@param fn string
---@return integer?
---@return string?
local curAddAppFile = function(fn, ...)
    expect(1, fn, "string")
    return addAppFile(fn, runningpid, nil, ...)
end

---Show a popup
---@param title string
---@param body string
---@return integer? pid
function popup(title, body)
    expect(1, title, "string")
    expect(2, body, "string")
    local pid = addAppFile("remos/popup.lua", runningpid, nil, title, body)
    return pid
end

---Set the title of a process
---@param pid integer
---@param title string
local function setProcessTitle(pid, title)
    if not processes[pid] then
        return
    end
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
    ---@return integer pid
    addProcess = function(fn, title)
        expect(1, fn, "function")
        expect(2, title, "string")
        return addProcess(fn, title, runningpid)
    end,
    ---If this program was started from a file, get the name of that file
    ---@return string
    getRunningProgram = function()
        return processes[runningpid].file
    end,
    ---Create a new foreground process
    ---@param fn function
    ---@param title string
    ---@return integer pid
    addApp = function(fn, title)
        expect(1, fn, "function")
        expect(2, title, "string")
        return addApp(fn, title, runningpid)
    end,
    addAppFile = curAddAppFile,
    ---Create a new foreground app processs
    ---@param fn string
    ---@param env table
    ---@param ... any
    ---@return integer?
    addAppFileEnv = function(fn, env, ...)
        expect(1, fn, "function")
        expect(2, env, "table")
        return addAppFile(fn, runningpid, env, ...)
    end,
    setFocused = setFocused,
    cleanupProcess = cleanupProcess,
    terminateProcess = terminateProcess,
    ---Set the title of a process
    ---@param title string
    ---@param pid integer? defaults to current
    setTitle = function(title, pid)
        expect(1, title, "string")
        expect(2, pid, "number", "nil")
        setProcessTitle(pid or runningpid, title)
    end,
    ---Set this app to terminate when it loses focus.
    terminateOnFocusLoss = function()
        terminateOnFocusLoss(runningpid)
    end,
    popup = popup,
    ---Queue a notification
    ---@param icon string Single character icon
    ---@param content string
    notification = function(icon, content)
        notifications[#notifications + 1] = {
            content = content,
            icon = icon,
            pid = runningpid,
            title = processes[runningpid].title
        }
        os.queueEvent("remos_notification")
    end,
    ---Set information about the playing audio
    ---@param title string?
    ---@param paused boolean?
    setPlaying = function(title, paused)
        peripheralStatus.playing = title
        peripheralStatus.paused = paused
        os.queueEvent("remos_peripheral")
    end,
    loadTheme = function()
        local tui = require "touchui"
        local darkMode = settings.get("remos.dark_mode")
        if darkMode then
            tui.theme.bg = colors.black
            tui.theme.fg = colors.white
            tui.theme.highlight = colors.orange
            tui.theme.inputbg = colors.gray
            tui.theme.inputfg = colors.white
        else
            tui.theme.bg = colors.white
            tui.theme.fg = colors.black
            tui.theme.highlight = colors.blue
            tui.theme.inputbg = colors.lightGray
            tui.theme.inputfg = colors.black
        end
        tui.theme.barbg, tui.theme.barfg = tui.theme.bg, tui.theme.fg
        local customThemeFile = settings.get("remos.custom_theme_file")
        local customTheme
        if customThemeFile then
            customTheme = remos.loadTable(customThemeFile)
        end
        if customTheme then
            for k, v in pairs(customTheme) do
                -- perform lookup
                if type(v) == "string" then
                    customTheme[k] = colors[v]
                end
            end
            tui.theme.bg = customTheme.bg or tui.theme.bg
            tui.theme.fg = customTheme.fg or tui.theme.fg
            tui.theme.highlight = customTheme.highlight or tui.theme.highlight
            tui.theme.inputbg = customTheme.inputbg or tui.theme.inputbg
            tui.theme.inputfg = customTheme.inputfg or tui.theme.inputfg
        end
        if customTheme then
            tui.theme.barfg = customTheme.barfg or tui.theme.fg
            tui.theme.barbg = customTheme.barbg or tui.theme.bg
        end
        if settings.get("remos.invert_bar_colors") then
            tui.theme.barfg, tui.theme.barbg = tui.theme.barbg, tui.theme.barfg
        end
        _G.remos.theme = tui.theme
    end,

    --- variables to get information about the current process
    pid = 0,
    ppid = 0,

    --- audio volume global
    volume = 1,

    ---- Random utilities

    ---Load a table from a file
    ---@param fn string
    ---@return table?
    ---@return string?
    loadTable = function(fn)
        expect(1, fn, "string")
        local f, err = fs.open(fn, "rb")
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
    ---Write a table to a file
    ---@param fn string
    ---@param t table
    ---@param compact boolean? Default true
    ---@return boolean?
    ---@return string?
    saveTable = function(fn, t, compact)
        expect(1, fn, "string")
        expect(2, t, "table")
        if compact == nil then
            compact = true
        end
        local st = textutils.serialise(t, { compact = compact })
        local f, err = fs.open(fn, "wb")
        if not f then
            return nil, err
        end
        f.write(st)
        f.close()
        return true
    end,
    ---Create a deep clone of a table
    ---@param t table
    ---@return table
    deepClone = function(t)
        expect(1, t, "table")
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
    removeFromTable = removeFromArray,
    ---Get the configured timezone's epoch in ms
    ---@param time integer? UTC epoch to apply timezone to. Defaults to current time.
    epoch = function(time)
        local tz = settings.get("remos.timezone")
        time = time or os.epoch("utc")
        return time + (tz * 60 * 60 * 1000)
    end,
    ---Load an icon
    ---@param fn string
    ---@param fg color?
    ---@param bg color?
    ---@return BLIT?
    ---@return string?
    loadTransparentBlit = function(fn, fg, bg)
        local icon, reason = remos.loadTable(fn)
        local bgchar = colors.toBlit(remos.theme.bg or bg)
        local fgchar = colors.toBlit(remos.theme.fg or fg)
        if icon --[[@as BLIT]] then
            for _, v in ipairs(icon) do
                v[2] = string.gsub(v[2], " ", bgchar)
                v[3] = string.gsub(v[3], " ", bgchar)
                v[2] = string.gsub(v[2], "_", fgchar)
                v[3] = string.gsub(v[3], "_", fgchar)
            end
        end
        return icon --[[@as BLIT]]
    end
}

local function assertPeripheralOwnership()
    if not findInArray(peripheralStatus.usedBy, runningpid) and peripheralStatus.attached == "speaker" and #peripheralStatus.usedBy > 0 then
        local usedby = peripheralStatus.usedBy[1]
        error(("Peripheral is in use by %s (pid:%d)."):format(processes[usedby].title, usedby), 2)
    end
end

local function assertCanChangePeripheral()
    if not (#peripheralStatus.usedBy == 0 or
            #peripheralStatus.usedBy == 1 and findInArray(peripheralStatus.usedBy, runningpid)) then
        error("Peripheral is being used by other and cannot be ejected.", 2)
    end
end

--- Pocket injection
if pocket then
    local oldequip = pocket.equipBack
    local oldunequip = pocket.unequipBack
    _G.pocket.equipBack = function()
        assertCanChangePeripheral()
        local v = oldequip()
        updatePeripheral()
        return v
    end
    _G.pocket.unequipBack = function()
        assertCanChangePeripheral()
        if #peripheralStatus.usedBy > 1 then
            error("This peripheral is being used by others.")
        end
        local v = oldunequip()
        updatePeripheral()
        return v
    end
    _G.peripheral.wrap = function(side)
        if side ~= "back" then
            return oldwrap(side)
        end
        assertPeripheralOwnership()
        updatePeripheral() -- ensure the peripheral type is up to date
        peripheralStatus.usedBy[#peripheralStatus.usedBy + 1] = runningpid
        peripheralStatus.playing = nil
        peripheralStatus.paused = true
        return oldwrap(side)
    end
end

--- multishell injection
--- TODO fix this, it does not work

--[[
multishell.getCount = function()
    return #apps
end

multishell.getCurrent = function()
    return runningpid
end

multishell.getTitle = function(pid)
    if processes[pid] then
        return processes[pid].title
    end
end

multishell.getFocus = function()
    return focusedpid
end

multishell.launch = function(env, path, ...)
    return addAppFile(path, runningpid, env, ...)
end

multishell.setFocus = function(pid)
    setFocused(pid)
end

multishell.setTitle = function(pid, title)
    setProcessTitle(pid, title)
end
]]

---- Internal API
---@class RemosInternalAPI
local remosInternalAPI = {
    -- TODO find a better way to expose apps and processes
    _apps = apps,
    _processes = processes,
    ---Create a new process with a window assigned to it
    ---Internal because it uses the window position to offset mouse events
    ---and Apps already have an offset window, causing problems.
    ---@param fn function
    ---@param title string
    ---@param win Window?
    ---@return integer pid
    _addProcess = function(fn, title, win)
        return addProcess(fn, title, runningpid, win)
    end,
    ---Set the pid of the which process is "home"
    ---Internal because only init should set this.
    ---@param pid integer
    _setHomePid = function(pid)
        removeFromArray(apps, processes[pid])
        homepid = pid
    end,
    ---Set the pid of the which process is the notification tray
    ---Internal because only init should set this.
    ---@param pid integer
    _setNotificationPid = function(pid)
        removeFromArray(apps, processes[pid])
        notificationpid = pid
    end,
    ---Set the pid of the which process is "menu"
    ---Internal because only init should set this.
    ---@param pid integer
    _setMenuPid = function(pid)
        removeFromArray(apps, processes[pid])
        menupid = pid
    end,
    ---Set the pid of the which process is the top bar
    ---Internal because only init should set this.
    _setTopBarPid = function(pid)
        topbarpid = pid
    end,
    ---Set the pid of the which process is the bottom bar
    ---Internal because only init should set this.
    _setBottomBarPid = function(pid)
        processes[pid].y = 1
        bottombarpid = pid
    end,
    ---Expose the status of the peripheral to the top bar
    _peripheralStatus = peripheralStatus,
    ---Expose the notifications to the top bar + notificationPane application
    _notifications = notifications
}

setmetatable(_G.remos, remosInternalAPI)

--- Overwrite package.path in all newly made instances of require
local olddofile = dofile
_G.dofile = function(filename)
    if filename ~= "rom/modules/main/cc/require.lua" then
        return olddofile(filename)
    end
    local req = olddofile(filename)
    return {
        make = function(env, dir)
            local shellrequire, shellpackage = req.make(env, dir)
            ---@diagnostic disable-next-line: inject-field, need-check-nil
            shellpackage.path = shellpackage.path .. ";/libs/?.lua/;/libs/?/init.lua"
            return shellrequire, shellpackage
        end
    }
end

processes[0] = {
    pid = 0,
    ppid = 0,
    children = {},
    coro = coroutine.create(function() while true do os.pullEvent("do_not_ever_queue_this_event_thanks") end end),
    cyclesAlive = 0,
    file = "/remos/kernel.lua",
    title = "KERNEL",
    lastExeTime = 0,
    maxExeTime = 0,
    meanExeTime = 0,
    state = "alive",
    totalExeTime = 0,
    x = 1,
    y = 1
}

--- load palette
local themeFile = settings.get("remos.custom_palette_file")
if themeFile then
    local t = remos.loadTable(themeFile)
    if t then
        for k, v in pairs(t) do
            term.setPaletteColor(colors[k], v)
            applicationWin.setPaletteColor(colors[k], v)
        end
    end
end

remos.loadTheme()
loadfile("remos/splash.lua", "t", _ENV)()

initpid = addProcess(assert(loadfile("remos/init.lua", "t", _ENV)), "INIT", 0)
processes[initpid].file = "/remos/init.lua"

os.queueEvent("remos_boot")
runProcesses()
print("REMOS has exited.")
