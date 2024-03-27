local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local testWin = window.create(term.current(), 1, 1, term.getSize())


local rootvbox = container.vBox()
rootvbox:setWindow(testWin)

local icon = "*"
rootvbox:addWidget(input.inputWidget("Icon", nil, function(value)
    icon = value
end))

local text = ""
rootvbox:addWidget(input.inputWidget("Text", nil, function(value)
    text = value
end))

rootvbox:addWidget(input.buttonWidget("Send!", function(self)
    remos.notification(icon, text)
end))

tui.run(rootvbox)
