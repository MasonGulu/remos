local tui = require("touchui")
local container = require("touchui.containers")
local list = require("touchui.lists")
local draw = require("draw")
local input = require("touchui.input")
local rootWin = window.create(term.current(), 1, 1, term.getSize())

local rootVbox = container.vBox()
rootVbox:setWindow(rootWin)
local settingVbox = container.scrollableVBox()
rootVbox:addWidget(settingVbox)
local footerText = tui.textWidget("* Requires restart", "l")
rootVbox:addWidget(footerText, 1)

local function settingUpdateOnEvent(name)
    return function(value)
        settings.set(name, value)
    end
end

local function toggleSetting(label, name)
    settingVbox:addWidget(input.toggleWidget(label, settingUpdateOnEvent(name), settings.get(name)), 2)
end
toggleSetting("Dark Mode", "remos.dark_mode")
toggleSetting("Inverse Buttons", "remos.invert_buttons")
toggleSetting("Large Home Icons", "remos.home.large_icons")

local saveButton = input.buttonWidget("Save", function(self)
    settings.save()
    os.queueEvent("settings_update")
end)
rootVbox:addWidget(saveButton, 3)

tui.run(rootVbox, nil, nil, true)
