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

---Create a popup to ask for a file
---@param label any
---@param path any
---@param mandatory boolean if you cannot exit this popup without selecting a file (via pressing back)
---@return string? filepath
local function filePopup(label, path, mandatory)
    local rootWin = window.create(term.current(), 1, 1, term.getSize())
    path = path or "/"

    local rootVbox = container.vBox()
    rootVbox:setWindow(rootWin)

    local titleText = tui.textWidget(label, "c")
    rootVbox:addWidget(titleText, 1)

    local pathText = tui.textWidget(path, "c")
    rootVbox:addWidget(pathText, 1)
    local updatePath

    ---@type string?
    local selectedFile

    local fileList = list.listWidget(fs.list(path), 1, function(win, x, y, w, h, item, theme)
        draw.set_col(theme.fg, theme.bg, win)
        if fs.isDir(fs.combine(path, item)) then
            draw.set_col(theme.highlight, nil, win)
        end
        draw.text(x, y, item, win)
    end, function(index, item)
        local filePath = fs.combine(path, item)
        if fs.isDir(filePath) then
            updatePath(filePath)
        else
            rootVbox.exit = true
            selectedFile = filePath
        end
    end, function(index, item)
        local filePath = fs.combine(path, item)
        rootVbox.exit = true
        selectedFile = filePath
    end)
    local fileBox = container.framedBox(fileList)
    rootVbox:addWidget(fileBox)

    function updatePath(newPath)
        if not fs.exists(newPath) then
            return
        end
        path = newPath
        local files = fs.list(path)
        for i, v in ipairs(files) do
            if fs.isDir(fs.combine(path, v)) then
                files[i] = v .. "/"
            end
        end
        if path == "" then path = "/" end
        if path ~= "/" then
            table.insert(files, 1, "..")
        end
        fileList:setTable(files)
        pathText:updateText(path)
    end

    updatePath(path)

    tui.run(rootVbox, nil, function(event)
        if event == "back_button" then
            if mandatory and (path == "" or path == "/") then
                -- already at the root
                rootVbox.exit = true
            end
            updatePath(fs.combine(path, ".."))
        end
    end)

    return selectedFile
end

return {
    listPopup = listPopup,
    filePopup = filePopup
}
