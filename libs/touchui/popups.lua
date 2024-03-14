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

---Create a confirmation popup
---@param title string
---@param description string
---@return boolean
local function confirmationPopup(title, description)
    local rootWin = window.create(term.current(), 1, 1, term.getSize())
    local vbox = container.vBox()
    local rootBox = container.framedBox(vbox)
    rootBox:setWindow(rootWin)

    local titleText = tui.textWidget(title, "c")
    vbox:addWidget(titleText, 2)
    local bodyVbox = container.scrollableVBox()
    vbox:addWidget(bodyVbox)
    local bodyText = tui.textWidget(description, "l")
    local lines = #require "cc.strings".wrap(description, bodyVbox.w)
    bodyVbox:addWidget(bodyText, lines + 1)

    local buttonHbox = container.hBox()
    vbox:addWidget(buttonHbox, 3)
    local confirmed = false
    local noButton = input.buttonWidget("No", function(self)
        confirmed = false
        rootBox.exit = true
    end)
    buttonHbox:addWidget(noButton)
    local yesButton = input.buttonWidget("Yes", function(self)
        confirmed = true
        rootBox.exit = true
    end)
    buttonHbox:addWidget(yesButton)

    tui.run(rootBox, false)
    return confirmed
end

---Create a popup to ask for a file
---@param label any
---@param path any
---@param mandatory boolean if you cannot exit this popup without selecting a file (via pressing back)
---@param write boolean?
---@param allowDirs boolean? Allow the user to select/create directories
---@return string? filepath
local function filePopup(label, path, mandatory, write, allowDirs)
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
        elseif not write or confirmationPopup(("Overwrite %s?"):format(filePath), "This will overwrite this file. Are you sure?") then
            rootVbox.exit = true
            selectedFile = filePath
        end
    end, function(index, item)
        local filePath = fs.combine(path, item)
        local isDir = fs.isDir(filePath)
        if isDir and not allowDirs then
            return
        end
        if isDir or not write or confirmationPopup(("Overwrite %s?"):format(filePath), "This will overwrite this file. Are you sure?") then
            rootVbox.exit = true
            selectedFile = filePath
        end
    end)
    local fileBox = container.framedBox(fileList)
    rootVbox:addWidget(fileBox)

    local filenameInput, newfileHbox
    if allowDirs or write then
        filenameInput = input.inputWidget("New Name?")
        rootVbox:addWidget(filenameInput, 2)
        newfileHbox = container.hBox()
        rootVbox:addWidget(newfileHbox, 1)
        local newfolderButton = input.buttonWidget("+Folder", function(self)
            local newpath = fs.combine(path, filenameInput.value)
            filenameInput:setValue("")
            fs.makeDir(newpath)
            updatePath(newpath)
        end, nil, false)
        newfileHbox:addWidget(newfolderButton)
    end
    if write then
        local newfileButton = input.buttonWidget("+File", function(self)
            if #filenameInput.value > 0 then
                rootVbox.exit = true
                selectedFile = fs.combine(path, filenameInput.value)
                filenameInput:setValue("")
            end
        end, nil, false)
        newfileHbox:addWidget(newfileButton)
    end

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

    tui.run(rootVbox, not mandatory, function(event)
        if event == "back_button" then
            if mandatory and (path == "" or path == "/") then
                -- already at the root
                rootVbox.exit = true
            end
            updatePath(fs.combine(path, ".."))
        end
    end, true)

    return selectedFile
end

return {
    listPopup = listPopup,
    filePopup = filePopup,
    confirmationPopup = confirmationPopup
}
