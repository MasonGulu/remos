--- Home screen
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")
local homeWin = window.create(term.current(), 1, 1, term.getSize())

settings.define("remos.menu.close_all_button", {
    description = "Show a close all button in the menu",
    type = "boolean",
    default = true
})
settings.define("remos.menu.item_height", {
    description = "Menu item height",
    type = "number",
    default = 8
})

---@type RemosInternalAPI
local _remos = getmetatable(remos)

local rootVbox = container.vBox()
rootVbox:setWindow(homeWin)

local inbox = list.listWidget(_remos._apps, settings.get("remos.menu.item_height"),
    function(win, x, y, w, h, item, theme)
        draw.text(x, y, ("%d>%d %s"):format(item.ppid, item.pid, item.title), win)
        -- draw.text(x, y + 1, ("%d>%d"):format(item.ppid, item.pid), win)
        draw.set_col(theme.fg, theme.bg, win)
        for i = 1, h - 1 do
            win.setCursorPos(x, y + i)
            win.blit(item.window.getLine(i))
        end
        draw.set_col(theme.fg, theme.bg, win)
        draw.text(x, y + h - 1, ("\140"):rep(w), win)
    end, function(index, item)
        remos.setFocused(item.pid)
    end, nil, function(i, proc)
        remos.cleanupProcess(proc.pid)
    end, function(i, proc)
        if proc.state == "alive" then
            remos.terminateProcess(proc.pid)
        else
            remos.cleanupProcess(proc.pid)
        end
    end)
rootVbox:addWidget(inbox)

if settings.get("remos.menu.close_all_button") then
    local closeAllButton = input.buttonWidget("Close All", function(self)
        local apps = remos.deepClone(_remos._apps)
        for id, proc in ipairs(apps) do
            remos.terminateProcess(proc.pid)
        end
    end, nil, true, "c")
    rootVbox:addWidget(closeAllButton, 3)
end

tui.run(rootVbox, nil, nil, true)
