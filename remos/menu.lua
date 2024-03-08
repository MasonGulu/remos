--- Home screen
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("touchui.draw")
local homeWin = window.create(term.current(), 1, 1, term.getSize())

local inbox = list.listWidget(remos._apps, 8, function(win, x, y, w, h, item, theme)
    draw.text(x, y, ("%s"):format(item.title), win)
    -- draw.text(x, y + 1, ("pid=%d;ppid=%d;state=%s"):format(item.pid, item.ppid, item.state), win)
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
inbox:setWindow(homeWin)

tui.run(inbox)
