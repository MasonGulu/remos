local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")

---@type RemosInternalAPI
local _remos = getmetatable(remos)

settings.define("remos.dark_mode", {
    description = "Dark mode",
    type = "boolean",
    default = false
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
    os.queueEvent("menu_button")
end, function() end, false)
home_button = input.buttonWidget("\186", function()
    os.queueEvent("home_button")
end, function() end, false)
back_button = input.buttonWidget("<", function()
    os.queueEvent("back_button")
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

local function timeText()
    return os.date(settings.get("remos.top_bar.time_format"), remos.epoch() / 1000) --[[@as string]]
end

---@type TextWidget
local timeLabel
local topBarHBox = container.hBox()
local topBarProcess = function()
    topBarHBox:setWindow(topBarWin)
    timeLabel = tui.textWidget(timeText(), "l")
    topBarHBox:addWidget(timeLabel)
    topBarHBox:setTheme(barTheme)
    tui.run(topBarHBox, false)
end
local topBarpid = _remos._addProcess(topBarProcess, "topBarUI", topBarWin)
remos.setFocused(topBarpid)
_remos._setTopBarPid(topBarpid)

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
    barTheme = {
        fg = tui.theme.bg,
        bg = tui.theme.fg
    }
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
end
reloadSettings()

local menupid = assert(remos.addAppFile("remos/menu.lua"))
_remos._setMenuPid(menupid)

local homepid = assert(remos.addAppFile("remos/home.lua"))
_remos._setHomePid(homepid)

local timer = os.startTimer(1)
while true do
    local e, id = os.pullEvent()
    if e == "menu_button" then
        remos.setFocused(menupid)
    elseif e == "home_button" then
        -- remos.addAppFile("rom/programs/shell.lua")
        -- remos.addAppFile("browser.lua")
        remos.setFocused(homepid)
    elseif e == "timer" and id == timer then
        timer = os.startTimer(1)
    elseif e == "settings_update" then
        reloadSettings()
    end
    timeLabel:updateText(timeText())
end
