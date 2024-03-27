local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")
local popups = require("touchui.popups")
local homeWin = window.create(term.current(), 1, 1, term.getSize())


---@class Shortcut
---@field iconLarge BLIT?
---@field iconLargeFile string?
---@field iconSmall BLIT?
---@field iconSmallFile string?
---@field label string
---@field path string

local function saveShortcuts(shortcuts)
    for i, v in ipairs(shortcuts) do
        v.iconSmall = nil
        v.iconLarge = nil
    end
    assert(remos.saveTable("config/home_apps.table", shortcuts, false))
end


local defaultIconLarge = assert(remos.loadTransparentBlit("icons/default_icon_large.blit"))
local defaultIconSmall = assert(remos.loadTransparentBlit("icons/default_icon_small.blit"))

local unknownIconLarge = assert(remos.loadTransparentBlit("icons/unknown_icon_large.blit"))
local unknownIconSmall = assert(remos.loadTransparentBlit("icons/unknown_icon_small.blit"))

local function loadShortcuts()
    local shortcuts = assert(remos.loadTable("config/home_apps.table"))
    for i, v in ipairs(shortcuts) do
        if v.iconSmallFile then
            v.iconSmall = remos.loadTransparentBlit(v.iconSmallFile)
            v.iconLarge = v.iconSmall
            v.iconSmall = v.iconSmall or unknownIconSmall
        end
        if v.iconLargeFile then
            v.iconLarge = remos.loadTransparentBlit(v.iconLargeFile) or v.iconLarge or unknownIconLarge
        end
    end
    return shortcuts
end

local shortcuts = loadShortcuts()
local gridList

---Update/create/delete a shortcut
---@param index integer
---@param label string?
---@param path string?
---@param iconSmallFile string?
---@param iconLargeFile string?
local function shortcutMenu(index, label, path, iconSmallFile, iconLargeFile)
    local rootWin = window.create(term.current(), 1, 1, term.getSize())
    local rootVbox = container.vBox()
    rootVbox:setWindow(rootWin)

    local labelInput = input.inputWidget("Label")
    rootVbox:addWidget(labelInput, 2)
    labelInput:setValue(label or "")

    local pathPicker = input.fileWidget("Path", nil, nil, "lua")
    pathPicker.selected = path
    rootVbox:addWidget(pathPicker, 2)

    local iconSmallFilePicker = input.fileWidget("Small Icon", nil, nil, "blit", nil, "icons")
    iconSmallFilePicker.selected = iconSmallFile
    rootVbox:addWidget(iconSmallFilePicker, 2)

    local iconLargeFilePicker = input.fileWidget("Large Icon", nil, nil, "blit", nil, "icons")
    iconLargeFilePicker.selected = iconLargeFile
    rootVbox:addWidget(iconLargeFilePicker, 2)

    local deleteButton = input.buttonWidget("Delete", function(self)
        table.remove(shortcuts, index)
        saveShortcuts(shortcuts)
        shortcuts = loadShortcuts()
        gridList:setTable(shortcuts)
        rootVbox.exit = true
    end)
    rootVbox:addWidget(deleteButton)
    local cancelButton = input.buttonWidget("Cancel", function(self)
        rootVbox.exit = true
    end)
    rootVbox:addWidget(cancelButton)
    local saveButton = input.buttonWidget("Save", function(self)
        if type(labelInput.value) == "string" and type(pathPicker.selected) == "string" then
            shortcuts[index] = {
                label = labelInput.value,
                path = pathPicker.selected,
                iconSmallFile = iconSmallFilePicker.selected,
                iconLargeFile = iconLargeFilePicker.selected
            }
        else
            remos.addAppFile("remos/popup.lua", "Error!",
                "Label and Path are both required to be filled to save this shortcut!")
        end
        saveShortcuts(shortcuts)
        shortcuts = loadShortcuts()
        gridList:setTable(shortcuts)
        rootVbox.exit = true
    end)
    rootVbox:addWidget(saveButton)

    tui.run(rootVbox, true, nil, true)
end

settings.define("remos.home.large_icons", {
    description = "Use large icons for home screen (3x3 instead of 4x4)",
    type = "boolean",
    default = false
})

local homeSize = 4
if settings.get("remos.home.large_icons") then
    homeSize = 3
end

gridList = list.gridListWidget(shortcuts, homeSize, homeSize, function(win, x, y, w, h, item, theme)
    local icon
    if homeSize == 3 then
        icon = item.iconLarge or defaultIconLarge
    else
        icon = item.iconSmall or defaultIconSmall
    end
    draw.draw_blit(x, y, icon, win)
    draw.text(x, y + h - 1, item.label, win)
end, function(index, item)
    remos.addAppFile(item.path)
end, function(index, item)
    shortcutMenu(index, item.label, item.path, item.iconSmallFile, item.iconLargeFile)
end)
gridList:setWindow(homeWin)

tui.run(gridList, nil, function(event)
    if event == "settings_update" then
        homeSize = 4
        if settings.get("remos.home.large_icons") then
            homeSize = 3
        end
        gridList:updateGridSize(homeSize, homeSize)
        shortcuts = loadShortcuts()
        gridList:setTable(shortcuts)
        defaultIconLarge = assert(remos.loadTransparentBlit("icons/default_icon_large.blit"))
        defaultIconSmall = assert(remos.loadTransparentBlit("icons/default_icon_small.blit"))
    elseif event == "add_home_shortcut" then
        shortcutMenu(#shortcuts + 1)
    end
end, true)
