local tui = require "touchui"
local theme = tui.theme
local draw = require "touchui.draw"

---@param widget Widget
---@param x integer
---@param y integer
---@return integer
---@return integer
local function repositionCords(widget, x, y)
    -- assert(type(widget) == "table", debug.traceback("Widget not table!"))
    return x - widget.x + 1, y - widget.y + 1
end
local function genericMouse(name, button, x, y)
    return function(_, i, widget)
        local rx, ry = repositionCords(widget, x, y)
        return widget[name](widget, button, rx, ry)
    end
end

---@class WidgetBox : Widget
local genericBox__index = setmetatable({}, tui.emptyWidget_meta)

---@param fun fun(self:Widget,i:integer,widget:Widget): boolean? exit
function genericBox__index:iterateWidgets(fun)
    if self.cellCount == 0 then return end
    for i = 1, self.cellCount do
        local widget = self.widgets[i]
        if widget then
            if fun(self, i, widget) then
                return true
            end
        end
    end
end

function genericBox__index:dragStart(button, sx, sy, nx, ny)
    return self:iterateWidgets(function(self, i, widget)
        local rsx, rsy = repositionCords(widget, sx, sy)
        local rnx, rny = repositionCords(widget, nx, ny)
        return widget:dragStart(button, rsx, rsy, rnx, rny)
    end)
end

function genericBox__index:calculateCellSize(i)
    local sum = 0
    local cells = 0
    self.autoCellSize[i] = true
    for _, v in pairs(self.cellSizes) do
        cells = cells + 1
        sum = sum + v
    end
    local remainingHeight = self[self.dir] - sum
    if self.cellCount - cells == 1 then
        -- last cell
        self.cellSizes[i] = remainingHeight
    else
        self.cellSizes[i] = math.floor(remainingHeight / (self.cellCount - cells))
    end
    return self.cellSizes[i]
end

function genericBox__index:updateCellPos()
    local sum = 1
    for i = 1, self.cellCount do
        self.cellPos[i] = sum
        sum = sum + (self.cellSizes[i] or self:calculateCellSize(i))
    end
end

function genericBox__index:resetCellSizes()
    for i, v in pairs(self.cellSizes) do
        if self.autoCellSize[i] then
            self.cellSizes[i] = nil
        end
    end
end

---@param widget Widget
function genericBox__index:updateWidgetWin(i, widget)
    local cellSize = self.cellSizes[i]
    local win
    local x, y, w, h
    if self.dir == "h" then
        x, y, w, h = 1, self.cellPos[i], self.w, cellSize
    else
        x, y, w, h = self.cellPos[i], 1, cellSize, self.h
    end
    if widget.window then
        win = widget.window
        widget.window.reposition(x, y, w, h)
    else
        win = window.create(self.window, x, y, w, h)
    end
    widget:setWindow(win)
end

function genericBox__index:drag(button, x, y)
    return self:iterateWidgets(genericMouse("drag", button, x, y))
end

function genericBox__index:dragEnd(button, x, y)
    return self:iterateWidgets(genericMouse("dragEnd", button, x, y))
end

function genericBox__index:longPress(button, x, y)
    return self:iterateWidgets(genericMouse("longPress", button, x, y))
end

function genericBox__index:shortPress(button, x, y)
    return self:iterateWidgets(genericMouse("shortPress", button, x, y))
end

function genericBox__index:scroll(dir, x, y)
    return self:iterateWidgets(genericMouse("scroll", dir, x, y))
end

function genericBox__index:char(ch)
    return self:iterateWidgets(function(_, i, widget)
        return widget:char(ch)
    end)
end

function genericBox__index:key(code)
    return self:iterateWidgets(function(_, i, widget)
        return widget:key(code)
    end)
end

local genericBox_meta = { __index = genericBox__index }

function genericBox__index:setTheme(th)
    self.theme = tui.applyThemePassthrough(th or theme)
    self:iterateWidgets(function(_, i, widget)
        widget:setTheme(self.theme)
    end)
end

function genericBox__index:setWindow(win)
    assert(win, debug.traceback())
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    self:resetCellSizes()
    self:updateCellPos()
    self:iterateWidgets(self.updateWidgetWin)
end

---Add a widget to this
---@param wid Widget
---@param size integer?
function genericBox__index:addWidget(wid, size)
    self.cellCount = self.cellCount + 1
    self.widgets[self.cellCount] = wid
    self.cellSizes[self.cellCount] = size
    self.autoCellSize[self.cellCount] = nil
    assert(wid.setTheme, debug.traceback("no theme?"))
    wid:setTheme(self.theme)
    self:resetCellSizes()
    self:updateCellPos()
    self:iterateWidgets(self.updateWidgetWin)
end

function genericBox__index:draw()
    self.window.setVisible(false)
    draw.set_col(theme.fg, theme.bg, self.window)
    self.window.clear()
    local blinking, x, y = false, nil, nil
    local blinkfg, blinkbg
    self:iterateWidgets(function(self, integer, widget)
        widget:draw()
        if widget.window.getCursorBlink() then
            x, y = widget.window.getCursorPos()
            y = y + widget.y - 1
            blinking = true
            blinkfg, blinkbg = draw.get_col(widget.window)
        end
    end)
    if blinking then
        self.window.setCursorPos(x, y)
        draw.set_col(blinkfg, blinkbg, self.window)
    end
    self.window.setCursorBlink(blinking)
    self.window.setVisible(true)
    self.window.setVisible(false)
end

---@param dir "h"|"w"
---@return WidgetBox
local function genericBox(dir)
    ---@class WidgetBox
    local self = setmetatable(tui.emptyWidget(), genericBox_meta)
    self.cellCount = 0
    self.dir = dir
    ---@type Widget[]
    self.widgets = {}
    self.cellPos = {}
    self.cellSizes = {}
    self.autoCellSize = {}

    return self
end

local function vBox()
    return genericBox("h")
end

local function hBox()
    return genericBox("w")
end

---@class ScrollableWidgetBox : WidgetBox
local genericScrollableBox__index = setmetatable({}, tui.emptyWidget_meta)
local genericScrollableBox_meta = { __index = genericScrollableBox__index }



function genericScrollableBox__index:updateMaxScroll()
    local dir = self[self.dir]
    self.maxScroll = math.max(self.totalHeight - dir, 0)
    self.barSize = math.floor(math.max(math.min(dir * (dir / self.totalHeight), dir), 1))
end

function genericScrollableBox__index:repositionWindow()
    if self.dir == "h" then
        self.parentWindow.reposition(1, -self.scrolledY + 1, self.w - 1, self.totalHeight)
    else
        self.parentWindow.reposition(-self.scrolledY + 1, 1, self.totalHeight, self.h - 1)
    end
    -- self.parent:setWindow(self.parentWindow)
end

function genericScrollableBox__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    if self.dir == "h" then
        self.parentWindow = window.create(win, 1, -self.scrolledY + 1, self.w - 1, self.totalHeight)
    else
        self.parentWindow = window.create(win, -self.scrolledY + 1, 1, self.totalHeight, self.h - 1)
    end
    self:updateMaxScroll()
    self.parent:setWindow(self.parentWindow)
end

---Add a widget
---@param wid Widget
---@param h integer
function genericScrollableBox__index:addWidget(wid, h)
    self.totalHeight = self.totalHeight + h
    self:updateMaxScroll()
    self.parent:addWidget(wid, h)
    self:repositionWindow()
end

function genericScrollableBox__index:setScroll(v)
    self.scrolledY = math.min(math.max(v, 0), self.maxScroll)
    self:repositionWindow()
end

function genericScrollableBox__index:repositionCords(x, y)
    if self.dir == "w" then
        return x - self.parent.x + 1 + self.scrolledY, y - self.parent.y + 1
    else
        return x - self.parent.x + 1, y - self.parent.y + 1 + self.scrolledY
    end
end

function genericScrollableBox__index:cursorInBox(x, y)
    return x >= 1 and x <= self.w and y >= 1 and y <= self.h
end

function genericScrollableBox__index:dragStart(button, sx, sy, nx, ny)
    local psx, psy = self:repositionCords(sx, sy)
    local pnx, pny = self:repositionCords(nx, ny)
    local dragUsed = self.parent:dragStart(button, psx, psy, pnx, pny)
    if not dragUsed then
        if (self.dir == "w" and sy ~= ny) or (self.dir == "h" and sx ~= nx) then
            return false
        end
        if not self:cursorInBox(sx, sy) then
            return false
        end
        if self.maxScroll == 0 then
            self:setScroll(0)
            return false
        end
        self.dragging = true
        if self.dir == "h" then
            self.dragY = sy
            self.startScroll = self.scrolledY
            self:setScroll(self.startScroll + self.dragY - ny)
        else
            self.dragY = sx
            self.startScroll = self.scrolledY
            self:setScroll(self.startScroll + self.dragY - nx)
        end
        return true
    end
    return dragUsed
end

function genericScrollableBox__index:drag(button, x, y)
    if self.dragging then
        if self.dir == "h" then
            self:setScroll(self.startScroll + self.dragY - y)
        else
            self:setScroll(self.startScroll + self.dragY - x)
        end
        return true
    else
        return self.parent:drag(button, self:repositionCords(x, y))
    end
end

function genericScrollableBox__index:dragEnd(button, x, y)
    if self.dragging then
        if self.dir == "h" then
            self:setScroll(self.startScroll + self.dragY - y)
        else
            self:setScroll(self.startScroll + self.dragY - x)
        end
        self.dragging = false
        return true
    else
        return self.parent:dragEnd(button, self:repositionCords(x, y))
    end
end

function genericScrollableBox__index:shortPress(button, x, y)
    return self.parent:shortPress(button, self:repositionCords(x, y))
end

function genericScrollableBox__index:longPress(button, x, y)
    return self.parent:longPress(button, self:repositionCords(x, y))
end

function genericScrollableBox__index:scroll(dir, x, y)
    local scrollUsed = self.parent:scroll(dir, self:repositionCords(x, y))
    if (not scrollUsed) and self:cursorInBox(x, y) then
        self:setScroll(self.scrolledY + dir)
        return true
    end
    return scrollUsed
end

function genericScrollableBox__index:draw()
    self.window.setVisible(false)
    draw.set_col(theme.fg, theme.bg, self.window)
    self.window.clear()
    if self.scrolledY > 0 then
        if self.dir == "h" then
            draw.text(self.w, 1, "\24", self.window)
        else
            draw.text(1, self.h, "\27", self.window)
        end
    end
    if self.scrolledY < self.maxScroll then
        if self.dir == "h" then
            draw.text(self.w, self.h, "\25", self.window)
        else
            draw.text(self.w, self.h, "\26", self.window)
        end
    end
    if self.dir == "h" then
        local sy = 2 + (self.h - self.barSize - 2) * (self.scrolledY / self.maxScroll)
        for i = 0, self.barSize - 1 do
            draw.text(self.w, sy + i, "\127", self.window)
        end
    else
        local x = 2 + (self.w - self.barSize - 2) * (self.scrolledY / self.maxScroll)
        draw.text(x, self.h, ("\127"):rep(self.barSize), self.window)
    end
    self.parent:draw()
    local blinking = self.parent.window.getCursorBlink()
    local x, y = self.parent.window.getCursorPos()
    if blinking then
        self.window.setCursorPos(x, y - self.scrolledY)
    end
    self.window.setVisible(true)
end

function genericScrollableBox__index:setTheme(th)
    self.parent:setTheme(th)
end

function genericScrollableBox__index:char(ch)
    return self.parent:char(ch)
end

function genericScrollableBox__index:key(ch)
    return self.parent:key(ch)
end

---Create a scrollable VBox
---@return ScrollableWidgetBox
local function genericScrollableBox(dir)
    local parent = genericBox(dir)
    ---@class ScrollableWidgetBox
    local self = setmetatable(tui.emptyWidget(), genericScrollableBox_meta)
    self.parent = parent
    self.dir = dir
    self.totalHeight = 0
    self.scrolledY = 0

    return self
end

---@return ScrollableWidgetBox
local function scrollableVBox()
    return genericScrollableBox("h")
end

---@return ScrollableWidgetBox
local function scrollableHBox()
    return genericScrollableBox("w")
end

---@class FramedBoxWidget : Widget
---@field contentWin Window
---@field content Widget
local framedBox__index = setmetatable({}, tui.emptyWidget_meta)
local framedBox_meta = { __index = framedBox__index }

---@param self FramedBoxWidget
local function updateContent(self)
    self.contentWin = window.create(self.window, 3, 3, self.w - 4, self.h - 4)
    self.content:setWindow(self.contentWin)
end

function framedBox__index:setWindow(win)
    self.window = win
    self.w, self.h = win.getSize()
    self.x, self.y = win.getPosition()
    updateContent(self)
end

function framedBox__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    draw.square(2, 2, self.w - 2, self.h - 2, self.window)
    self.content:draw()
    self.window.setVisible(true)
    self.window.setVisible(false)
end

local function genericMouseBox(name)
    ---@param self FramedBoxWidget
    return function(self, button, rx, ry)
        return self.content[name](self.content, button, rx, ry - 2)
    end
end

framedBox__index.drag = genericMouseBox("drag")
framedBox__index.dragStart = function(self, button, sx, sy, x, y)
    return self.content:dragStart(button, sx - 2, sy - 2, x - 2, y - 2)
end
framedBox__index.dragEnd = genericMouseBox("dragEnd")
framedBox__index.shortPress = genericMouseBox("shortPress")
framedBox__index.longPress = genericMouseBox("longPress")
framedBox__index.scroll = genericMouseBox("scroll")

function framedBox__index:key(code)
    return self.content:key(code)
end

function framedBox__index:char(ch)
    return self.content:char(ch)
end

---Create a FramedBox
---@param content Widget
---@return FramedBoxWidget
local function framedBox(content)
    local self = setmetatable(tui.emptyWidget(), framedBox_meta)
    self.content = content
    return self
end

return {
    vBox = vBox,
    hBox = hBox,
    scrollableVBox = scrollableVBox,
    scrollableHBox = scrollableHBox,
    framedBox = framedBox
}
