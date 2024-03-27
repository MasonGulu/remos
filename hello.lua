local tui = require("touchui")
local rootWin = window.create(term.current(), 1, 1, term.getSize())

local rootText = tui.textWidget("Hello World!", "c")
rootText:setWindow(rootWin)

tui.run(rootText)
