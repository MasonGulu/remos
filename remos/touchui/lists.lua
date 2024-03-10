local tui = require "touchui"
local theme = tui.theme
local draw = require "touchui.draw"

---@class GenericListWidget : Widget
---@field getLayout fun(self: GenericListWidget, index: integer): x: integer, y: integer, w:integer, h:integer
---@field postDraw fun(self: GenericListWidget)
---@field updateTable fun(self: GenericListWidget)
---@field getItem fun(self: GenericListWidget, x: integer, y: integer): index: integer?
local genericListWidget__index = setmetatable({}, tui.emptyWidget_meta)
local genericListWidget_meta = { __index = genericListWidget__index }


function genericListWidget__index:draw()
    self.window.setVisible(false)
    draw.set_col(self.theme.fg, self.theme.bg, self.window)
    self.window.clear()
    self:updateTable()
    for i = 1, #self.table do
        local x, y, w, h = self:getLayout(i)
        self.drawItem(self.window, x, y, w, h, self.table[i], self.theme)
    end
    self:postDraw()
    self.window.setVisible(true)
end

function genericListWidget__index:cursorInBox(x, y)
    return x >= 1 and x <= self.w and y >= 1 and y <= self.h
end

function genericListWidget__index:setTable(t)
    self.table = t
    self:updateTable()
end

function genericListWidget__index:shortPress(button, x, y)
    if self:cursorInBox(x, y) and self.onShortPress then
        local i = self:getItem(x, y)
        if not i then
            return
        end
        if self.onShortPress then
            self.onShortPress(i, self.table[i])
        end
    end
end

function genericListWidget__index:longPress(button, x, y)
    if self:cursorInBox(x, y) and self.onLongPress then
        local i = self:getItem(x, y)
        if not i then
            return
        end
        if self.onLongPress then
            self.onLongPress(i, self.table[i])
        end
    end
end

---@class ListWidget : GenericListWidget
local listWidget__index = setmetatable({}, genericListWidget_meta)
local listWidget_meta = { __index = listWidget__index }

function listWidget__index:getLayout(i)
    local y = ((i - 1) * self.itemH) + 1 - self.scrolledY
    local x = 1
    if self.draggingItem == i then
        x = self.dragEndX - self.dragStartX + 1
    end
    return x, y, self.w, self.itemH
end

function listWidget__index:postDraw()
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
end

function listWidget__index:updateTable()
    assert(self.table, debug.traceback("No item?"))
    local totalHeight = #self.table * self.itemH
    self.maxScroll = math.max(totalHeight - self.h, 0)
    self.barSize = math.floor(math.max(math.min(self.h * (self.h / totalHeight), self.h), 1))
    self.scrolledY = math.min(self.scrolledY, self.maxScroll)
end

function listWidget__index:setScroll(v)
    self:updateTable()
    self.scrolledY = math.min(math.max(v, 0), self.maxScroll)
end

---Get an item a given y coordinate coresponds with
---@param y integer
---@return integer?
function listWidget__index:getItem(_, y)
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
        self.draggingItem = self:getItem(sx, sy)
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

---@class GridListWidget : GenericListWidget
local gridListWidget__index = setmetatable({}, genericListWidget_meta)
local gridListWidget_meta = { __index = gridListWidget__index }

function gridListWidget__index:getItem(x, y)
    local itemsPerPage = self.pagew * self.pageh
    local itemWidth = math.floor(self.w / self.pagew)
    local itemHeight = math.floor((self.h - 1) / self.pageh)

    local itemPage = self.page
    local itemColumn = math.floor((x - 1) / itemWidth)
    local itemRow = math.floor((y - 1) / itemHeight)

    local adjustedIndex = (itemPage - 1) * itemsPerPage + itemRow * self.pagew + itemColumn + 1

    if y > self.h - 2 then
        return
    end

    if not self.table[adjustedIndex] then
        return
    end

    return adjustedIndex
end

function gridListWidget__index:getLayout(i)
    local itemsPerPage = self.pagew * self.pageh
    local itemWidth = math.floor(self.w / self.pagew)
    local itemHeight = math.floor((self.h - 1) / self.pageh)

    -- 0 INDEXED
    local itemPage = math.floor((i - 1) / itemsPerPage)
    -- index of item on its respective page
    local adjustedIndex = i - (itemPage * itemsPerPage) - 1

    -- 0 INDEXED
    local itemRow = math.floor(adjustedIndex / self.pagew)
    -- 0 INDEXED
    local itemColumn = adjustedIndex % self.pagew

    local pageX = (itemPage - self.page + 1) * itemWidth * self.w

    local itemX = (itemColumn * itemWidth) - pageX + 1
    local itemY = (itemRow * itemHeight) + 1

    if self.dragging then
        itemX = itemX + self.dragEndX - self.dragStartX
    end

    return itemX, itemY, itemWidth, itemHeight
end

function gridListWidget__index:updateTable()
    self.pages = math.floor(#self.table / (self.pagew * self.pageh)) + 1
end

function gridListWidget__index:postDraw()
    local str = ""
    for i = 1, self.pages do
        if self.page == i then
            str = str .. " \7 "
        else
            str = str .. "\186"
        end
    end
    draw.center_text(self.h, str, self.window)
end

function gridListWidget__index:dragStart(button, sx, sy, nx, ny)
    if not self:cursorInBox(sx, sy) then
        return false
    end
    self.dragging = true
    self.dragStartX = sx
    self.dragEndX = nx
    return true
end

function gridListWidget__index:drag(button, x, y)
    if self.dragging then
        self.dragEndX = x
        return true
    end
end

function gridListWidget__index:dragEnd(button, x, y)
    if self.dragging then
        local draggedDistance = self.dragEndX - self.dragStartX
        if draggedDistance > self.w / 3 then
            self.page = math.max(self.page - 1, 1)
        elseif draggedDistance < -self.w / 3 then
            self.page = math.min(self.page + 1, self.pages)
        end
        self.dragging = false
        return true
    end
end

function gridListWidget__index:scroll(dir, x, y)
    if self:cursorInBox(x, y) then
        self.page = math.max(math.min(self.page + dir, self.pages), 1)
        return true
    end
end

---@generic T : any
---@param t T[]
---@param pagew integer
---@param pageh integer
---@param drawItem fun(win:Window,x:integer,y:integer,w:integer,h:integer,item:T,theme:table<string,integer>)
---@param onShortPress fun(index:integer,item:T)?
---@param onLongPress fun(index:integer,item:T)?
---@return GridListWidget
local function gridListWidget(t, pagew, pageh, drawItem, onShortPress, onLongPress)
    ---@class GridListWidget
    local self = setmetatable(tui.emptyWidget(), gridListWidget_meta)
    -- 1 INDEXED
    self.table = t
    self.page = 1
    self.onShortPress = onShortPress
    self.onLongPress = onLongPress
    self.pagew = pagew
    self.pageh = pageh
    self.drawItem = drawItem

    return self
end

return {
    listWidget = listWidget,
    gridListWidget = gridListWidget
}
