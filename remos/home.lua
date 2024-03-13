local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")
local homeWin = window.create(term.current(), 1, 1, term.getSize())


---@class Shortcut
---@field iconLarge BLIT?
---@field iconLargeFile string?
---@field iconSmall BLIT?
---@field iconSmallFile string?
---@field label string
---@field path string

---Load an icon
---@param fn any
---@return BLIT?
---@return string?
local function loadIcon(fn)
    local f, err = fs.open(fn, "r")
    if not f then
        return nil, err
    end
    local t = f.readAll()
    if not t then
        return nil, "Empty file"
    end
    local icon = textutils.unserialise(t)
    f.close()
    return icon --[[@as BLIT]]
end

local function loadShortcuts()
    local shortcuts = assert(remos.loadTable("config/home_apps.table"))
    for i, v in ipairs(shortcuts) do
        if v.iconSmallFile then
            v.iconSmall = assert(loadIcon(v.iconSmallFile))
        end
        if v.iconLargeFile then
            v.iconLarge = assert(loadIcon(v.iconLargeFile))
        end
    end
    return shortcuts
end

local defaultIconLarge = assert(loadIcon("icons/default_icon_large.blit"))
local defaultIconSmall = assert(loadIcon("icons/default_icon_small.blit"))
local shortcuts = loadShortcuts()

local homeSize = 4

local gridList = list.gridListWidget(shortcuts, homeSize, homeSize, function(win, x, y, w, h, item, theme)
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
end)
gridList:setWindow(homeWin)

tui.run(gridList)
