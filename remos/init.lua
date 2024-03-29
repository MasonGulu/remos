local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")

---@type RemosInternalAPI
local _remos = getmetatable(remos)

assert(remos.pid == 1, "Remos INIT is already running.")

settings.define("remos.dark_mode", {
    description = "Dark mode",
    type = "boolean",
    default = false
})
settings.define("remos.custom_theme_file", {
    description = "File containting a custom theme table",
    type = "string"
})
settings.define("remos.invert_bar_colors", {
    description = "Invert the colors of the top/bottom bars",
    type = "boolean",
    default = true
})
settings.define("remos.invert_buttons", {
    description = "Dark mode",
    type = "boolean",
    default = false
})
local inverseButtons, darkMode, barTheme


local termW, termH = term.getSize()

local topBarWin = window.create(term.current(), 1, 1, termW, 1)
local bottomBarWin = window.create(term.current(), 1, termH, termW, 1)

local bottomBarHBox = container.hBox()
local menu_button, home_button, back_button
menu_button = input.buttonWidget("\127", function()
    os.queueEvent("remos_menu_button")
end, function() end, false)
home_button = input.buttonWidget("\186", function()
    os.queueEvent("remos_home_button")
end, function() end, false)
back_button = input.buttonWidget("<", function()
    os.queueEvent("remos_back_button")
end, function() end, false)
bottomBarHBox:setWindow(bottomBarWin)
bottomBarHBox:setTheme(barTheme)
local bottomBarProcess = function()
    tui.run(bottomBarHBox, false)
end
local bottomBarpid = _remos._addProcess(bottomBarProcess, "bottomBarUI", bottomBarWin)
remos.setFocused(bottomBarpid)
_remos._setBottomBarPid(bottomBarpid)

settings.define("remos.top_bar.time_format", {
    description = "Time format to pass into os.date to display on the top bar",
    type = "string",
    default = "%R"
})

settings.define("remos.top_bar.use_ingame", {
    description = "Use the ingame time for the clock.",
    type = "boolean",
    default = false
})

local function timeText()
    local time = settings.get("remos.top_bar.use_ingame") and os.epoch("ingame") or remos.epoch()
    local ok, s = pcall(os.date, settings.get("remos.top_bar.time_format"), time / 1000)
    return ok and s or "INVALID" --[[@as string]]
end

local function periphText()
    local attached = _remos._peripheralStatus.attached
    return attached == "modem" and "\23" or attached == "speaker" and "\14" or "_"
end

local function notificationText()
    local t = ""
    for i, v in ipairs(_remos._notifications) do
        t = t .. v.icon
    end
    return t
end

---@type TextWidget
local timeLabel, notificationLabel
---@type ButtonWidget
local periphLabel
local topBarHBox = container.hBox()
local topBarProcess = function()
    topBarHBox:setWindow(topBarWin)
    if pocket then
        periphLabel = input.buttonWidget(periphText(), function(self)
            pcall(pocket.equipBack)
        end, function(self)
            pcall(pocket.unequipBack)
        end, false, "l")
        topBarHBox:addWidget(periphLabel, 2)
    end
    timeLabel = tui.textWidget(timeText(), "l")
    topBarHBox:addWidget(timeLabel)
    notificationLabel = tui.textWidget(notificationText(), "r")
    topBarHBox:addWidget(notificationLabel)
    topBarHBox:setTheme(barTheme)
    tui.run(topBarHBox, false, function(...)
        local e, _, x, y = ...
        if e == "remos_notification" then
            notificationLabel:updateText(notificationText())
        elseif e == "remos_peripheral" and pocket then
            periphLabel:setLabel(periphText())
            periphLabel:setTheme({
                fg = #_remos._peripheralStatus.usedBy > 0 and remos.theme.highlight or remos.theme.barfg,
                bg = remos.theme.barbg
            })
        elseif e == "mouse_click" and y == 1 and x > 1 then
            os.queueEvent("remos_notification_pane")
        end
    end)
end
local topBarpid = _remos._addProcess(topBarProcess, "topBarUI", topBarWin)
remos.setFocused(topBarpid)
_remos._setTopBarPid(topBarpid)

---@alias CustomTheme {bg:color?,fg:color?,highlight:color?,inputbg:color?,inputfg:color?,barbg:color?,barfg:color?}

local function reloadSettings()
    darkMode = settings.get("remos.dark_mode")
    inverseButtons = settings.get("remos.invert_buttons")
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
    barTheme = {}
    barTheme.fg = tui.theme.fg
    barTheme.bg = tui.theme.bg
    if customTheme then
        barTheme.fg = customTheme.barfg or barTheme.fg
        barTheme.bg = customTheme.barbg or barTheme.bg
    end
    if settings.get("remos.invert_bar_colors") then
        barTheme.fg, barTheme.bg = barTheme.bg, barTheme.fg
    end
    tui.theme.barfg = barTheme.fg
    tui.theme.barbg = barTheme.bg
    bottomBarHBox:clearWidgets()
    if inverseButtons then
        bottomBarHBox:addWidget(menu_button)
        bottomBarHBox:addWidget(home_button)
        bottomBarHBox:addWidget(back_button)
    else
        bottomBarHBox:addWidget(back_button)
        bottomBarHBox:addWidget(home_button)
        bottomBarHBox:addWidget(menu_button)
    end
    bottomBarHBox:setTheme(barTheme)
    topBarHBox:setTheme(barTheme)
    if periphLabel then
        periphLabel:setTheme({
            fg = #_remos._peripheralStatus.usedBy > 0 and remos.theme.highlight or remos.theme.barfg,
            bg = remos.theme.barbg
        })
    end
    _G.remos.theme = tui.theme
end
reloadSettings()

local menupid = assert(remos.addAppFile("remos/menu.lua"))
_remos._setMenuPid(menupid)

local notificationpid = assert(remos.addAppFile("remos/notificationTray.lua"))
_remos._setNotificationPid(notificationpid)

local homepid = assert(remos.addAppFile("remos/home.lua"))
_remos._setHomePid(homepid)


local timer = os.startTimer(1)
while true do
    local e, id, _, y = os.pullEvent()
    if e == "remos_menu_button" then
        remos.setFocused(menupid)
    elseif e == "remos_home_button" then
        remos.setFocused(homepid)
    elseif e == "timer" and id == timer then
        timer = os.startTimer(1)
    elseif e == "settings_update" then
        reloadSettings()
    elseif e == "remos_notification_pane" then
        remos.setFocused(notificationpid)
    end
    timeLabel:updateText(timeText())
end
