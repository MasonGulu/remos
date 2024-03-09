local args = { ... }
local containers = require "touchui.containers"
local tui = require "touchui"
local w, h = term.getSize()
local rootWin = window.create(term.current(), 1, 1, w, h)


local title = args[1] or "Default Message"
local body = args[2] --or ""
tui.log(body)

local vbox = containers.vBox()
local rootBox = containers.framedBox(vbox)
rootBox:setWindow(rootWin)

local titleText = tui.textWidget(title, "c")
vbox:addWidget(titleText, 2)
local bodyVbox = containers.scrollableVBox()
vbox:addWidget(bodyVbox)
local bodyText = tui.textWidget(body, "l")
local lines = #require "cc.strings".wrap(body, bodyVbox.w)
bodyVbox:addWidget(bodyText, lines + 1)
local footer = tui.textWidget(("Thrown by PID: %s"):format(remos.ppid), "c")
vbox:addWidget(footer, 1)

remos.terminateOnFocusLoss()

tui.run(rootBox, true)
