local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local testWin = window.create(term.current(), 1, 1, term.getSize())

local vbox = container.scrollableVBox()
local row1 = input.inputWidget("text")
vbox:setWindow(testWin)
vbox:addWidget(row1, 5)
local toggle = input.toggleWidget("toggle", function(state)
    error("toggled!")
end)
vbox:addWidget(toggle, 5)
local slider = input.sliderWidget(1, 10, function() end)
local box = container.framedBox(slider)
vbox:addWidget(box, 7)
local row2 = input.inputWidget("text")
vbox:addWidget(row2, 5)
local row3 = input.inputWidget("text")
vbox:addWidget(row3, 5)

tui.run(vbox, true, nil, true)
