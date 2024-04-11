local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")
local popups = require("touchui.popups")
local homeWin = window.create(term.current(), 1, 1, term.getSize())


---@class Shortcut
---@field icon BLIT?
---@field iconFile string?
---@field label string
---@field path string

local function saveShortcuts(shortcuts)
    for i, v in ipairs(shortcuts) do
        v.icon = nil
    end
    assert(remos.saveTable("config/home_apps.table", shortcuts, false))
end


local defaultIcon = assert(remos.loadTransparentBlit("icons/default.icon"))

local unknownIcon = assert(remos.loadTransparentBlit("icons/missing.icon"))

local function loadShortcuts()
    ---@type Shortcut[]
    local shortcuts = assert(remos.loadTable("config/home_apps.table"))
    for i, v in ipairs(shortcuts) do
        if v.iconFile then
            v.icon = remos.loadTransparentBlit(v.iconFile) or unknownIcon
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
    rootVbox:addWidget(labelInput)
    labelInput:setValue(label or "")

    local pathPicker = input.fileWidget("Path", nil, nil, "lua")
    pathPicker.selected = path
    rootVbox:addWidget(pathPicker)

    local iconFilePicker = input.fileWidget("Icon", nil, nil, "icon", nil, "icons")
    iconFilePicker.selected = iconSmallFile
    rootVbox:addWidget(iconFilePicker)

    local deleteButton = input.buttonWidget("Delete", function(self)
        table.remove(shortcuts, index)
        saveShortcuts(shortcuts)
        shortcuts = loadShortcuts()
        gridList:setTable(shortcuts)
        rootVbox.exit = true
    end)
    rootVbox:addWidget(deleteButton, 3)
    local cancelButton = input.buttonWidget("Cancel", function(self)
        rootVbox.exit = true
    end)
    rootVbox:addWidget(cancelButton, 3)
    local saveButton = input.buttonWidget("Save", function(self)
        if type(labelInput.value) == "string" and type(pathPicker.selected) == "string" then
            shortcuts[index] = {
                label = labelInput.value,
                path = pathPicker.selected,
                iconFile = iconFilePicker.selected
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
    rootVbox:addWidget(saveButton, 3)

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

local strings = require "cc.strings"

gridList = list.gridListWidget(shortcuts, homeSize, homeSize, function(win, x, y, w, h, item, theme)
    local icon = item.icon or defaultIcon
    local iconx = math.floor((w - 5) / 2)
    local wrapped = strings.wrap(item.label, w - 1)
    local totalh = 3 + #wrapped
    local icony = math.max(math.floor((h - totalh) / 2), 1)
    draw.draw_blit(x + iconx, icony + y, icon, win)
    for i, t in ipairs(wrapped) do
        local toy = icony + i + 2
        if toy > h then
            break
        end
        local ty = toy + y
        local tx = x + math.floor((w - #t) / 2)
        draw.text(tx, ty, t, win)
    end
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
        defaultIcon = assert(remos.loadTransparentBlit("icons/default.icon"))
    elseif event == "add_home_shortcut" then
        shortcutMenu(#shortcuts + 1)
    end
end, true)
