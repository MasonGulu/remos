local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")

local darkMode = false
local inverseButtons = true

if darkMode then
    tui.theme.bg = colors.black
    tui.theme.fg = colors.white
    tui.theme.highlight = colors.orange
    tui.theme.inputbg = colors.gray
    tui.theme.inputfg = colors.white
end

local termW, termH = term.getSize()

local topBarWin = window.create(term.current(), 1, 1, termW, 1)
local bottomBarWin = window.create(term.current(), 1, termH, termW, 1)

local barTheme = {
    fg = tui.theme.bg,
    bg = tui.theme.fg
}


local bottomBarProcess = function()
    local bottomBarHBox = container.hBox()
    bottomBarHBox:setWindow(bottomBarWin)
    local menuButton = input.buttonWidget("\127", function()
        os.queueEvent("menuButton")
    end, function() end, false)
    local homeButton = input.buttonWidget("\186", function()
        os.queueEvent("homeButton")
    end, function() end, false)
    local backButton = input.buttonWidget("<", function()
        os.queueEvent("backButton")
    end, function() end, false)

    if inverseButtons then
        bottomBarHBox:addWidget(menuButton)
        bottomBarHBox:addWidget(homeButton)
        bottomBarHBox:addWidget(backButton)
    else
        bottomBarHBox:addWidget(backButton)
        bottomBarHBox:addWidget(homeButton)
        bottomBarHBox:addWidget(menuButton)
    end


    bottomBarHBox:setTheme(barTheme)
    tui.run(bottomBarHBox, false)
end
local bottomBarpid = remos.addProcess(bottomBarProcess, "bottomBarUI", bottomBarWin)
remos.setFocused(bottomBarpid)

---@type TextWidget
local timeText
local topBarProcess = function()
    local topBarHBox = container.hBox()
    topBarHBox:setWindow(topBarWin)
    timeText = tui.textWidget(os.date("%r") --[[@as string]], "c")
    topBarHBox:addWidget(timeText)
    topBarHBox:setTheme(barTheme)
    tui.run(topBarHBox, false)
end
local topBarpid = remos.addProcess(topBarProcess, "topBarUI", topBarWin)
remos.setFocused(topBarpid)

local menupid = remos.addAppFile("remos/menu.lua")
remos.setFocused(menupid)
-- hide menu from itself
remos._apps[1] = nil

local timer = os.startTimer(1)
while true do
    local e, id = os.pullEvent()
    if e == "menuButton" then
        remos.setFocused(menupid)
    elseif e == "homeButton" then
        -- remos.addAppFile("rom/programs/shell.lua")
        remos.addAppFile("browser.lua")
    elseif e == "timer" and id == timer then
        timer = os.startTimer(1)
    end
    timeText:updateText(os.date("%r"))
end
