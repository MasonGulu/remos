local tui        = require "touchui"
local input      = require "touchui.input"
local containers = require "touchui.containers"
local popups     = require "touchui.popups"
local rootWin    = window.create(term.current(), 1, 1, term.getSize())

local rootVbox   = containers.vBox()
rootVbox:setWindow(rootWin)

local scrollVbox = containers.scrollableVBox()
rootVbox:addWidget(scrollVbox)

scrollVbox:addWidget(tui.textWidget("Theme Editor", "c", 1), 6)

local buttonHbox = containers.hBox()
rootVbox:addWidget(buttonHbox, 3)

local wipTheme = {}

local colorInputs = {}
local function addColor(name)
    local colorInput = input.colorWidget(name, true, function(value)
        if value == 0 then
            wipTheme[name] = nil
        else
            wipTheme[name] = value
        end
    end)
    colorInputs[name] = colorInput
    colorInput:setColor(0)
    scrollVbox:addWidget(colorInput, 4)
end
addColor("fg")
addColor("bg")
addColor("barfg")
addColor("barbg")
addColor("checked")
addColor("unchecked")
addColor("inputbg")
addColor("inputfg")
addColor("hightlight")

local function loadTheme(t)
    wipTheme = t
    for k, v in pairs(wipTheme) do
        if type(v) == "string" then
            wipTheme[k] = colors[v]
        end
    end
    for k, v in pairs(colorInputs) do
        v:setColor(wipTheme[k] or 0)
    end
end

local colorLut = {}
for k, v in pairs(colors) do
    colorLut[v] = k
end

local function saveTheme(fn)
    local tosave = remos.deepClone(wipTheme)
    for k, v in pairs(tosave) do
        tosave[k] = colorLut[v]
    end
    remos.saveTable(fn, tosave)
end

local loadButton = input.buttonWidget("Load", function(self)
    local fn = popups.filePopup("Load Theme", "themes", false, false, false, "theme")
    if fn then
        local t = remos.loadTable(fn)
        if t then
            loadTheme(t)
        end
    end
end)
buttonHbox:addWidget(loadButton)
local saveButton = input.buttonWidget("Save", function(self)
    local fn = popups.filePopup("Save Theme", "themes", false, true, false, "theme")
    if fn then
        saveTheme(fn)
        os.queueEvent("settings_update") -- update the theme if we have it selected
    end
end)
buttonHbox:addWidget(saveButton)

tui.run(rootVbox, nil, nil, true)
