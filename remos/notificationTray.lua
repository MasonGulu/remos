--- Notification tray screen
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")
local homeWin = window.create(term.current(), 1, 1, term.getSize())


---@type RemosInternalAPI
local _remos = getmetatable(remos)

local rootVbox = container.vBox()
rootVbox:setWindow(homeWin)

local mediaVbox = container.vBox()
rootVbox:addWidget(mediaVbox, 5)

local mediaLabel = tui.textWidget("Nothing Playing.", "l")
mediaVbox:addWidget(mediaLabel)

local mediaHbox = container.hBox()
mediaVbox:addWidget(mediaHbox, 3)

local mediaButtonsHbox = container.hBox()
mediaHbox:addWidget(mediaButtonsHbox)

mediaButtonsHbox:addWidget(input.buttonWidget("\171", function(self)
    os.queueEvent("remos_skip_back_button")
end))
local playPauseButton = input.buttonWidget("\16", function(self)
    os.queueEvent("remos_play_pause_button")
end, nil, nil, "l")
mediaButtonsHbox:addWidget(playPauseButton)
mediaButtonsHbox:addWidget(input.buttonWidget("\187", function(self)
    os.queueEvent("remos_skip_forward_button")
end))
mediaHbox:addWidget(input.sliderWidget(0, 2, function(value)
    os.queueEvent("remos_volume_change", value)
    _G.remos.volume = value
end))

local inbox = list.listWidget(_remos._notifications, 3,
    function(win, x, y, w, h, item, theme)
        if y % 2 == 1 then
            draw.set_col(theme.inputfg, theme.inputbg, win)
        end
        draw.clear_line(y, win)
        draw.text(x, y, ("%s-%s"):format(item.icon, item.title), win)
        draw.clear_line(y + 1, win)
        draw.text(x, y + 1, item.content, win)
        draw.clear_line(y + 2, win)
        draw.text(x, y + h - 1, ("\140"):rep(w), win)
        draw.set_col(theme.fg, theme.bg, win)
    end, nil, nil, function(index, item)
        table.remove(_remos._notifications, index)
        os.queueEvent("remos_notification")
    end)
rootVbox:addWidget(inbox)

rootVbox:addWidget(input.buttonWidget("Settings", function(self)
    remos.addAppFile("remos/settings.lua")
end), 3)

tui.run(rootVbox, nil, function(e)
    if e == "remos_peripheral" then
        local t = _remos._peripheralStatus.playing
        mediaLabel:updateText(t and ("Playing: %s"):format(t) or "Nothing Playing.")
        local playicon = _remos._peripheralStatus.paused and "\16" or "\143"
        playPauseButton:setLabel(playicon)
    end
end, true)
