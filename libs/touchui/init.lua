---@class Widget
---@field dragStart fun(self:Widget,button:integer,sx:integer,sy:integer,nx:integer,ny:integer):boolean
---@field drag fun(self:Widget,button:integer,x:integer,y:integer):boolean
---@field dragEnd fun(self:Widget,button:integer,x:integer,y:integer):boolean
---@field shortPress fun(self:Widget,button:integer,x:integer,y:integer):boolean
---@field longPress fun(self:Widget,button:integer,x:integer,y:integer):boolean
---@field scroll fun(self:Widget,dir:integer,x:integer,y:integer):boolean
---@field char fun(self:Widget,ch:string): boolean
---@field key fun(self:Widget,code:integer): boolean
---@field setWindow fun(self:Widget,win: Window)
---@field setTheme fun(self:Widget,th: table<string,integer>?)
---@field theme table<string,integer>
---@field draw fun()
---@field exit boolean?
---@field window Window
---@field w integer
---@field h integer
---@field x integer
---@field y integer
local fe = require "fe"
local draw = require "draw"
local strings = require("cc.strings")
local expect = require("cc.expect").expect


local LONG_PRESS_TIME = 200
local TIMEOUT = 5000

local theme = (_G.remos and _G.remos.theme) or {
    bg = colors.white,
    fg = colors.black,
    checked = colors.green,
    unchecked = colors.red,
    inputbg = colors.lightGray,
    inputfg = colors.black,
    highlight = colors.blue,
}

local function log(s, ...)
    local f = assert(fs.open("log.txt", "a"))
    f.writeLine(s:format(...))
    f.close()
end

local function applyThemePassthrough(th)
    if th == theme then return theme end
    return setmetatable(th, { __index = theme })
end

local emptyWidget__index = {}
local emptyWidget_meta = { __index = emptyWidget__index }

function emptyWidget__index:setTheme(th)
    self.theme = applyThemePassthrough(th or theme)
end

function emptyWidget__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
end

local function nop() end
emptyWidget__index.dragStart = nop
emptyWidget__index.drag = nop
emptyWidget__index.dragEnd = nop
emptyWidget__index.shortPress = nop
emptyWidget__index.longPress = nop
emptyWidget__index.scroll = nop
emptyWidget__index.char = nop
emptyWidget__index.key = nop

function emptyWidget__index:draw()
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.setVisible(true)
    self.window.setVisible(false)
end

local function emptyWidget()
    local self = setmetatable({}, emptyWidget_meta)
    self.theme = theme
    return self
end

---@class TextWidget : Widget
local textWidget__index = setmetatable({}, emptyWidget_meta)
local textWidget_meta = { __index = textWidget__index }

function textWidget__index:updateText(t)
    self.text = t
    local divider = 1
    if self.scale > 0 then
        divider = 3 * self.scale
    end
    self.wrapped = strings.wrap(self.text, math.floor(self.w / divider))
    self.lines = #self.wrapped
end

function textWidget__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    self:updateText(self.text)
end

function textWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    local charw = 1
    if self.scale > 0 then
        charw = 3 * self.scale
    end
    self.window.clear()
    for i, t in ipairs(self.wrapped) do
        local x
        if self.alignment == "c" then
            x = math.floor((self.w - (#t * charw)) / 2)
        elseif self.alignment == "l" then
            x = 1
        elseif self.alignment == "r" then
            x = self.w - (#t * charw)
        end
        if self.scale == 0 then
            draw.text(x, i, t, self.window)
        else
            require("bigfont").writeOn(self.window, self.scale, t, x, i * self.scale)
        end
    end
    self.window.setVisible(true)
    self.window.setVisible(false)
end

---Create a simple widget that just displays text
---@param text string
---@param alignment "l"|"c"|"r"? left default
---@param scale integer? size (0 = default/normal, 1+ bigfont)
---@return TextWidget
local function textWidget(text, alignment, scale)
    expect(1, text, "string")
    expect(2, alignment, "string", "nil")
    ---@class TextWidget
    local self = setmetatable(emptyWidget(), textWidget_meta)
    self.alignment = alignment or "l"
    self.scale = scale or 0
    self.w = 50 -- w must be defined to call updateText.
    self:updateText(text)

    return self
end


---@param root Widget
---@param x integer
---@param y integer
---@return integer x
---@return integer y
local function offsetMouse(root, x, y)
    return x - root.x + 1, y - root.y + 1
end

---Quit running the UI
---@param root Widget
local function quit(root)
    expect(1, root, "table")
    root.exit = true
    -- os.queueEvent("touchui_quit")
end

---@param root Widget
---@param allowBack boolean?
---@param onEvent fun(...:any)?
---@param resizeToTerm boolean? resize the root.window to match term's size on term_resize
local function run(root, allowBack, onEvent, resizeToTerm)
    expect(1, root, "table")
    expect(2, allowBack, "boolean", "nil")
    expect(3, onEvent, "function", "nil")
    expect(4, resizeToTerm, 'boolean', "nil")
    local dragging = false
    ---@type integer
    local clickStartTime = os.epoch("utc")
    local dragStartX, dragStartY = 0, 0
    os.queueEvent("touchui_start")
    while true do
        root:draw()
        local e = fe.pullEvent(nil, TIMEOUT, false, true)
        if root.exit then
            return
        end
        if onEvent then
            onEvent(table.unpack(e, 1, e.n))
        end
        if not e then
            dragging = false -- timeout dragging if no activity
        elseif e.event == "term_resize" then
            -- if the root window was resized, then this will recalculate everything
            if resizeToTerm then
                root.window.reposition(1, 1, term.getSize())
            end
            root:setWindow(root.window)
        elseif e.event == "mouse_click" then
            clickStartTime = os.epoch("utc")
            dragStartX, dragStartY = offsetMouse(root, e.x, e.y)
        elseif e.event == "mouse_drag" then
            if not dragging then
                local dragX, dragY = offsetMouse(root, e.x, e.y)
                -- just started dragging
                -- make sure that the mouse actually moved before starting the drag
                if dragStartX ~= dragX or dragStartY ~= dragY then
                    root:dragStart(e.button, dragStartX, dragStartY, dragX, dragY)
                    dragging = true
                end
            else
                root:drag(e.button, offsetMouse(root, e.x, e.y))
            end
        elseif e.event == "mouse_up" then
            if dragging then
                root:dragEnd(e.button, offsetMouse(root, e.x, e.y))
                dragging = false
            else
                local time = os.epoch("utc")
                if time - clickStartTime + LONG_PRESS_TIME > TIMEOUT then
                    clickStartTime = time -- too long since mouse_click
                end
                if clickStartTime + LONG_PRESS_TIME <= time then
                    root:longPress(e.button, offsetMouse(root, e.x, e.y))
                else
                    root:shortPress(e.button, offsetMouse(root, e.x, e.y))
                end
            end
        elseif e.event == "back_button" and allowBack then
            return
        elseif e.event == "mouse_scroll" then
            root:scroll(e.dir, offsetMouse(root, e.x, e.y))
        elseif e.event == "char" then
            root:char(e.char)
        elseif e.event == "key" then
            root:key(e.key)
        end
    end
end


---Check if a value x,y falls between x1,y1 and x2,y2
---@param x integer
---@param y integer
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@return boolean
local function withinSquare(x, y, x1, y1, x2, y2)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

return {
    run = run,
    quit = quit,
    theme = theme,
    emptyWidget = emptyWidget,
    emptyWidget__index = emptyWidget__index,
    emptyWidget_meta = { __index = emptyWidget__index },
    textWidget = textWidget,
    applyThemePassthrough = applyThemePassthrough,
    log = log,
    withinSquare = withinSquare
}
