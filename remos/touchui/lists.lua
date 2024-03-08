local tui = require "touchui"
local theme = tui.theme
local draw = require "touchui.draw"

---@class ListWidget : Widget
local listWidget__index = setmetatable({}, tui.emptyWidget_meta)
local listWidget_meta = { __index = listWidget__index }

function listWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    self:updateMaxScroll()
    for i = 1, #self.table do
        local y = ((i - 1) * self.itemH) + 1 - self.scrolledY
        local x = 1
        if self.draggingItem == i then
            x = self.dragEndX - self.dragStartX + 1
        end
        self.drawItem(self.window, x, y, self.w, self.itemH, self.table[i], self.theme)
    end
    if self.scrolledY > 0 then
        draw.text(self.w, 1, "\24", self.window)
    end
    if self.scrolledY < self.maxScroll then
        draw.text(self.w, self.h, "\25", self.window)
    end
    local sy = 2 + (self.h - self.barSize - 2) * (self.scrolledY / self.maxScroll)
    for i = 0, self.barSize - 1 do
        draw.text(self.w, sy + i, "\127", self.window)
    end
    self.window.setVisible(true)
end

function listWidget__index:updateMaxScroll()
    assert(self.table, debug.traceback("No item?"))
    local totalHeight = #self.table * self.itemH
    self.maxScroll = math.max(totalHeight - self.h, 0)
    self.barSize = math.floor(math.max(math.min(self.h * (self.h / totalHeight), self.h), 1))
    self.scrolledY = math.min(self.scrolledY, self.maxScroll)
end

function listWidget__index:setScroll(v)
    self:updateMaxScroll()
    self.scrolledY = math.min(math.max(v, 0), self.maxScroll)
end

function listWidget__index:setTable(t)
    self.table = t
    self:updateMaxScroll()
end

function listWidget__index:cursorInBox(x, y)
    return x >= 1 and x <= self.w and y >= 1 and y <= self.h
end

---Get an item a given y coordinate coresponds with
---@param y integer
---@return integer?
function listWidget__index:getItem(y)
    local i = math.floor((y + self.scrolledY - 1) / self.itemH) + 1
    i = math.min(i, #self.table)
    if not self.table[i] then
        return
    end
    return i
end

function listWidget__index:dragStart(button, sx, sy, nx, ny)
    if not self:cursorInBox(sx, sy) then
        return false
    end
    if (sy == ny) and self.allowDragging then
        self.draggingItem = self:getItem(sy)
        if not self.draggingItem then
            return
        end
        self.dragStartX = sx
        self.dragEndX = nx
        return true
    elseif sy == ny then
        return false
    end
    if self.maxScroll == 0 then
        self:setScroll(0)
        return false
    end
    self.dragging = true
    self.dragY = sy
    self.startScroll = self.scrolledY
    self:setScroll(self.startScroll + self.dragY - ny)
    return true
end

function listWidget__index:drag(button, x, y)
    if self.dragging then
        self:setScroll(self.startScroll + self.dragY - y)
        return true
    elseif self.draggingItem then
        self.dragEndX = x
        return true
    end
end

function listWidget__index:dragEnd(button, x, y)
    if self.dragging then
        self:setScroll(self.startScroll + self.dragY - y)
        self.dragging = false
        return true
    elseif self.draggingItem then
        self.dragEndX = x
        -- TODO logic
        local diff = self.dragEndX - self.dragStartX
        if diff > self.w / 2 and self.onSwipeRight then
            self.onSwipeRight(self.draggingItem, self.table[self.draggingItem])
        elseif diff < -self.w / 2 and self.onSwipeLeft then
            self.onSwipeLeft(self.draggingItem, self.table[self.draggingItem])
        end
        self.draggingItem = nil
        return true
    end
end

function listWidget__index:shortPress(button, x, y)
    if self:cursorInBox(x, y) and self.onShortPress then
        local i = self:getItem(y)
        if not i then
            return
        end
        self.onShortPress(i, self.table[i])
    end
end

function listWidget__index:longPress(button, x, y)
    if self:cursorInBox(x, y) and self.onLongPress then
        local i = self:getItem(y)
        if not i then
            return
        end
        self.onLongPress(i, self.table[i])
    end
end

function listWidget__index:scroll(dir, x, y)
    if self:cursorInBox(x, y) then
        self:setScroll(self.scrolledY + dir)
        return true
    end
end

---@generic T : any
---@param t T[]
---@param itemH integer
---@param drawItem fun(win:Window,x:integer,y:integer,w:integer,h:integer,item:T,theme:table<string,integer>)
---@param onShortPress fun(index:integer,item:T)?
---@param onLongPress fun(index:integer,item:T)?
---@param onSwipeRight fun(index:integer,item:T)?
---@param onSwipeLeft fun(index:integer,item:T)?
---@return ListWidget
local function listWidget(t, itemH, drawItem, onShortPress, onLongPress, onSwipeRight, onSwipeLeft)
    ---@class ListWidget
    local self = setmetatable(tui.emptyWidget(), listWidget_meta)
    ---@type table
    self.table = t
    self.drawItem = drawItem
    self.onShortPress = onShortPress
    self.onLongPress = onLongPress
    self.onSwipeRight = onSwipeRight
    self.onSwipeLeft = onSwipeLeft
    self.allowDragging = not not (onSwipeLeft or onSwipeRight)
    self.itemH = itemH
    self.scrolledY = 0
    return self
end

return {
    listWidget = listWidget
}
