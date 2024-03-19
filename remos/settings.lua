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

local function label(t, alignment, scale)
    local h = 3
    scale = scale or 0
    if scale > 0 then h = (3 * scale) + 1 end
    settingVbox:addWidget(tui.textWidget(t, alignment, scale), h)
end

local function inputSetting(label, name, number)
    local inputWidget = input.inputWidget(label, number and tonumber, function(value)
        if number then
            value = tonumber(value)
            if not value then
                return
            end
        end
        settings.set(name, value)
    end)
    settingVbox:addWidget(inputWidget, 3)
    inputWidget:setValue(tostring(settings.get(name)))
end

label("UI", "c", 1)
toggleSetting("Dark Mode", "remos.dark_mode")
toggleSetting("Inverse Buttons", "remos.invert_buttons")
toggleSetting("Display in-game time", "remos.top_bar.use_ingame")
local timeFormatOptions = { "%I:%M %p", "%R", "%r", "%T" }
local timeFormatWidget = input.selectionWidget("Time Format", timeFormatOptions,
    function(win, x, y, w, h, item, theme)
        draw.text(x, y, item, win)
        local time = settings.get("remos.top_bar.use_ingame") and os.epoch("ingame") or remos.epoch()
        local formatted = os.date(item, time / 1000) --[[@as string]]
        draw.text(x + w - #formatted, y, formatted, win)
    end, settingUpdateOnEvent("remos.top_bar.time_format"))
settingVbox:addWidget(timeFormatWidget, 2)
inputSetting("UTC Timezone", "remos.timezone", tonumber)
---@diagnostic disable-next-line: undefined-global
if periphemu then
    toggleSetting("Use ns time units*", "remos.use_nano_seconds")
end
label("Home", "c", 1)
toggleSetting("Large Home Icons", "remos.home.large_icons")

settingVbox:addWidget(input.buttonWidget("Add Shortcut", function(self)
    os.queueEvent("add_home_shortcut")
    os.queueEvent("home_button")
end), 3)

local saveButton = input.buttonWidget("Save", function(self)
    settings.save()
    os.queueEvent("settings_update")
end)
rootVbox:addWidget(saveButton, 3)

tui.run(rootVbox, nil, nil, true)
