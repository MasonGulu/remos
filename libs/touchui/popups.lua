local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")

---@param label string
---@generic T : any
---@param t T[]
---@param itemH integer
---@param drawItem fun(win:Window,x:integer,y:integer,w:integer,h:integer,item:T,theme:table<string,integer>)
---@param middleWidget Widget?
---@return integer? i
---@return T? item
local function listPopup(label, t, itemH, drawItem, middleWidget)
    local rootWin = window.create(term.current(), 1, 1, term.getSize())
    local rootVbox = container.vBox()
    rootVbox:setWindow(rootWin)
    local titleText = tui.textWidget(label, "c")
    rootVbox:addWidget(titleText, 1)

    if middleWidget then
        rootVbox:addWidget(middleWidget)
    end
    local selectedIndex, selectedItem
    local itemList = list.listWidget(t, itemH, drawItem, function(index, item)
        selectedIndex = index
        selectedItem = item
        tui.quit(rootVbox)
    end)
    local box = container.framedBox(itemList)
    rootVbox:addWidget(box)

    tui.run(rootVbox, true)

    return selectedIndex, selectedItem
end

return {
    listPopup = listPopup
}
