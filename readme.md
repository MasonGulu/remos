# Remos
An Android inspired shell for ComputerCraft.

Featuring the popular game Empires of Dirt! (You can JUST install EOD with `wget run https://raw.githubusercontent.com/MasonGulu/remos/main/install_eod.lua`)

To install simply run `wget run https://raw.githubusercontent.com/MasonGulu/remos/main/install.lua`

If you find incompatibilites that are not listed below please report them. I can't promise 100% compatibility, but I'd like it to be as close as possible.

## Remos Specific Features
* Familiar Android-like interface
* High amounts of customizations.
* Multithreading with processes and a process tree.
* Access control / monitoring to peripherals.
* Process performance monitoring.
* Notification system.

## Writing Shell Specific Software
If you would like to leverage the abilities of remos, look in the `_G.remos` global for the publically exposed interfaces.

### Events
There are a few specific events that you can use in your programs.
* `remos_back_button` - When the back button is pressed.
* `remos_skip_back_button` - When the media controls skip back button is pressed
* `remos_skip_forward_button` - When the media controls skip forward button is pressed
* `remos_volume_change`, `number` - When the volume slider is changed. This value is also available at `_G.remos.volume`.

## Custom Themes
You can create custom themes by creating a lua table file in the `themes` directory. It must have the `.theme` extension. The customizable fields are as follows.
* `fg`
* `bg`
* `barfg`
* `barbg`
* `checked`
* `unchecked`
* `inputbg`
* `inputfg`
* `highlight`

## Incompatibilities
* `shell.getRunningProgram()` will return `remos/kernel.lua` unless it is ran through `shell`.
* As of right now multishell is not compatible and will actually run programs along side the remos kernel.

## TODO
Daemons

# TouchUI
This is my GUI library designed specifically for a touch oriented interface. It features horizontal and vertical containers of scrollable and non-scrollable varieties. It also contains a built in file browsing popup, and many different types of inputs.

## Hello World
```lua
local tui = require("touchui")
local rootWin = window.create(term.current(), 1, 1, term.getSize()) -- you must have a window to display on

local rootText = tui.textWidget("Hello World!", "c") -- create a text widget and center align the text
rootText:setWindow(rootWin) -- your root widget needs its window set manually

tui.run(rootText)
```

## Notification Test Demo
```lua
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local testWin = window.create(term.current(), 1, 1, term.getSize())


local rootvbox = container.vBox()
rootvbox:setWindow(testWin) -- setting the root widget's window

-- adding some input widgets to collect text
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
end), 3) -- passing in a height here

tui.run(rootvbox)
```
