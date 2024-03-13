local tui = require("touchui")
local draw = require "draw"

---@class ButtonWidget : Widget
local buttonWidget__index = setmetatable({}, tui.emptyWidget_meta)
local buttonWidget_meta = { __index = buttonWidget__index }

function buttonWidget__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    self.textY = math.ceil(self.h / 2)
end

function buttonWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    if self.border then
        draw.square(2, 1, self.w - 2, self.h, self.window)
    end
    if self.alignment == "c" then
        draw.center_text(self.textY, self.label, self.window)
    elseif self.alignment == "l" then
        local left = 1
        if self.border then left = 3 end
        draw.text(left, self.textY, self.label, self.window)
    elseif self.alignment == "r" then
        local right = self.w - 2
        if self.border then right = right - 1 end
        draw.text(right - #self.label, self.textY, self.label, self.window)
    end
    self.window.setVisible(true)
    self.window.setVisible(false)
end

function buttonWidget__index:isOnButton(x, y)
    return tui.withinSquare(x, y, 1, 1, self.w - 1, self.h)
end

function buttonWidget__index:shortPress(button, x, y)
    if self:isOnButton(x, y) then
        if self.onShortPress then
            self:onShortPress()
        end
        return true
    end
end

function buttonWidget__index:longPress(button, x, y)
    if self:isOnButton(x, y) then
        if self.onLongPress then
            self:onLongPress()
        end
        return true
    end
end

function buttonWidget__index:setLabel(label)
    self.label = label
end

---Create a button widget
---@param label string
---@param onShortPress fun(self:ButtonWidget)?
---@param onLongPress fun(self:ButtonWidget)?
---@param border boolean? true default
---@param alignment "l"|"c"|"r"? center default
---@return ButtonWidget
local function buttonWidget(label, onShortPress, onLongPress, border, alignment)
    ---@class ButtonWidget
    local self = setmetatable(tui.emptyWidget(), buttonWidget_meta)
    if border == nil then
        border = true
    end
    self.border = border
    self.label = label
    self.onShortPress = onShortPress
    self.onLongPress = onLongPress
    self.alignment = alignment or "c"

    return self
end

---@class ToggleWidget : Widget
local toggleWidget__index = setmetatable({}, tui.emptyWidget_meta)
local toggleWidget_meta = { __index = toggleWidget__index }

function toggleWidget__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    self.textY = math.ceil(self.h / 2)
end

function toggleWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    draw.text(2, self.textY, self.label, self.window)
    local c = (self.state and self.theme.checked) or self.theme.unchecked
    if self.state then
        draw.text(self.w - 2, self.textY, "\140", self.window)
        draw.set_col(nil, c, self.window)
        draw.text(self.w - 1, self.textY, " ", self.window)
    else
        draw.text(self.w - 1, self.textY, "\140", self.window)
        draw.set_col(nil, c, self.window)
        draw.text(self.w - 2, self.textY, " ", self.window)
    end
    self.window.setVisible(true)
    self.window.setVisible(false)
end

function toggleWidget__index:shortPress(button, x, y)
    if x >= self.w - 2 and x <= self.w - 1 and y == self.textY then
        self.state = not self.state
        self.onUpdate(self.state)
    end
end

---Create a toggle switch widget
---@param label string
---@param onUpdate fun(state:boolean)
---@param state boolean?
---@return ToggleWidget
local function toggleWidget(label, onUpdate, state)
    ---@class ToggleWidget
    local self = setmetatable(tui.emptyWidget(), toggleWidget_meta)
    self.state = state
    self.onUpdate = onUpdate
    self.label = label

    return self
end

---@class SliderWidget : Widget
local sliderWidget__index = setmetatable({}, tui.emptyWidget_meta)
local sliderWidget_meta = { __index = sliderWidget__index }

function sliderWidget__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    self.sliderW = self.w - #self.label - 3
    self.sliderX = #self.label + 3
    self.sliderY = math.max(math.ceil(self.h / 2), 2)
end

function sliderWidget__index:updateSlider(nx)
    nx = nx - self.x
    self.value = math.min(math.max((nx - self.sliderX + 1) / (self.sliderW - 1), 0), 1)
    self.onUpdate(self.min + (self.value * (self.max - self.min)))
end

function sliderWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    draw.text(self.sliderX, self.sliderY, ("\140"):rep(self.sliderW), self.window)
    draw.text(self.sliderX + math.ceil(self.value * (self.sliderW - 1)), self.sliderY, "\157", self.window)
    draw.text(2, self.sliderY, self.label, self.window)
    self.window.setVisible(true)
    self.window.setVisible(false)
end

function sliderWidget__index:onSlider(x, y)
    return y == self.sliderY and x >= self.sliderX and x < self.sliderW + self.sliderX
end

function sliderWidget__index:dragStart(button, sx, sy, nx, ny)
    if self:onSlider(sx, sy) and ny == sy then
        self:updateSlider(nx)
        self.dragging = true
        return true
    end
end

function sliderWidget__index:drag(button, x, y)
    if self.dragging then
        self:updateSlider(x)
        return true
    end
end

function sliderWidget__index:dragEnd(button, x, y)
    if self.dragging then
        self:updateSlider(x)
        self.dragging = false
        return true
    end
end

function sliderWidget__index:scroll(dir, x, y)
    if self:onSlider(x, y) then
        self:updateSlider(self.sliderX + math.ceil(self.value * (self.sliderW - 1)) - dir)
        return true
    end
end

function sliderWidget__index:shortPress(button, x, y)
    if self:onSlider(x, y) then
        self:updateSlider(x)
        return true
    end
end

---@param min number
---@param max number
---@param onUpdate fun(value: number)
---@param label string?
---@return SliderWidget
local function sliderWidget(min, max, onUpdate, label)
    ---@class SliderWidget
    local self = setmetatable(tui.emptyWidget(), sliderWidget_meta)
    self.label = label or ""
    self.value = 0
    self.min, self.max = min, max
    self.onUpdate = onUpdate

    return self
end

---@class InputWidget : Widget
local inputWidget__index = setmetatable({}, tui.emptyWidget_meta)
local inputWidget_meta = { __index = inputWidget__index }

function inputWidget__index:shortPress(button, x, y)
    local centerY = math.floor(self.h / 2)
    if tui.withinSquare(x, y, 3 + #self.label, centerY, self.w - 1, centerY) then
        self.focused = true
        return true
    end
    self.focused = false
end

function inputWidget__index:updateScroll(dx)
    local fieldW = self.w - 3 - #self.label
    self.cursorPos = math.min(math.max(self.cursorPos + dx, 1), #self.value + 1)
    local newScroll = math.floor(self.cursorPos - (fieldW / 2))
    self.scrollPos = math.max(math.min(newScroll, #self.value - fieldW + 2), 1)
end

function inputWidget__index:char(ch)
    if self.focused then
        local newValue = self.value:sub(1, self.cursorPos - 1) .. ch .. self.value:sub(self.cursorPos, -1)
        if self.filter and not self.filter(newValue) then
            return -- does not match filter
        end
        self.value = newValue
        self:updateScroll(1)
        return true
    end
end

function inputWidget__index:key(code)
    if self.focused then
        if code == keys.backspace then
            self:updateScroll(-1)
            self.value = self.value:sub(1, self.cursorPos - 1) .. self.value:sub(self.cursorPos + 1, -1)
        elseif code == keys.left then
            self:updateScroll(-1)
        elseif code == keys.right then
            self:updateScroll(1)
        elseif code == keys.home then
            self:updateScroll(- #self.value)
        elseif code == keys["end"] then
            self:updateScroll(#self.value)
        end
        return true
    end
end

function inputWidget__index:draw()
    local leftX = 3 + #self.label
    local fieldW = self.w - 2 - #self.label
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    local centerY = math.floor(self.h / 2)
    draw.text(2, centerY, self.label, self.window)
    local t = self.value:sub(self.scrollPos, self.scrollPos + fieldW)
    draw.set_col(self.theme.inputfg, self.theme.inputbg, self.window)
    draw.text(leftX, centerY, require "cc.strings".ensure_width(t, fieldW), self.window)

    self.window.setCursorBlink(not not self.focused)
    local selectedX = self.cursorPos - self.scrollPos + leftX
    self.window.setCursorPos(selectedX, centerY)
    self.window.setVisible(true)
    self.window.setVisible(false)
end

---@alias textFilter fun(s:string):boolean

---Create a text input widget
---@param label string?
---@param filter textFilter?
---@return InputWidget
local function inputWidget(label, filter)
    ---@class InputWidget
    local self = setmetatable(tui.emptyWidget(), inputWidget_meta)
    self.filter = filter
    self.label = label or ""
    self.value = ""
    self.cursorPos = 1
    self.scrollPos = 1
    return self
end

return {
    toggleWidget = toggleWidget,
    buttonWidget = buttonWidget,
    sliderWidget = sliderWidget,
    inputWidget = inputWidget
}
