local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local list = require("touchui.lists")
local draw = require("draw")

local defaultPadding = 2

local function paddedWindow(padding)
    padding = padding or defaultPadding
    local termw, termh = term.getSize()
    return window.create(term.current(), padding + 1, padding + 1, termw - 2 * padding, termh - 2 * padding)
end

---@param label string
---@generic T : any
---@param t T[]
---@param itemH integer
---@param drawItem fun(win:Window,x:integer,y:integer,w:integer,h:integer,item:T,theme:table<string,integer>)
---@param middleWidget Widget?
---@param padding integer?
---@return integer? i
---@return T? item
local function listPopup(label, t, itemH, drawItem, middleWidget, padding)
    local rootWin = paddedWindow(padding)
    local rootVbox = container.vBox()
    local rootBox = container.framedBox(rootVbox)
    rootBox:setWindow(rootWin)
    local titleText = tui.textWidget(label, "c")
    rootVbox:addWidget(titleText, 1)

    if middleWidget then
        rootVbox:addWidget(middleWidget)
    end
    local selectedIndex, selectedItem
    local itemList = list.listWidget(t, itemH, drawItem, function(index, item)
        selectedIndex = index
        selectedItem = item
        tui.quit(rootBox)
    end)
    local box = container.framedBox(itemList)
    rootVbox:addWidget(box)

    tui.run(rootBox, true)

    return selectedIndex, selectedItem
end

---Create a confirmation popup
---@param title string
---@param description string
---@param padding integer?
---@return boolean
local function confirmationPopup(title, description, padding)
    local rootWin = paddedWindow(padding)
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

---Create a popup to ask for input
---@param title string
---@param description string
---@param label string?
---@param filter textFilter?
---@param padding integer?
---@return string?
local function inputPopup(title, description, label, filter, padding)
    local rootWin = paddedWindow(padding)
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

    local text
    local textInput = input.inputWidget(label, filter, function(value)
        text = value
        if text == "" then
            text = nil
        end
    end)
    vbox:addWidget(textInput, 2)

    local buttonHbox = container.hBox()
    vbox:addWidget(buttonHbox, 3)
    local cancelButton = input.buttonWidget("Cancel", function(self)
        text = nil
        rootBox.exit = true
    end)
    buttonHbox:addWidget(cancelButton)
    local submitButton = input.buttonWidget("Submit", function(self)
        rootBox.exit = true
    end)
    buttonHbox:addWidget(submitButton)

    tui.run(rootBox, true)
    return text
end

---Create a popup to ask for a file
---@param label any
---@param path any
---@param mandatory boolean if you cannot exit this popup without selecting a file (via pressing back)
---@param write boolean?
---@param allowDirs boolean? Allow the user to select/create directories
---@param extension string? Lock the file extension
---@param padding integer?
---@return string? filepath
local function filePopup(label, path, mandatory, write, allowDirs, extension, padding)
    local rootWin = paddedWindow(padding)
    path = path or "/"

    local rootVbox = container.vBox()
    local rootBox = container.framedBox(rootVbox)
    rootBox:setWindow(rootWin)

    local titleText = tui.textWidget(label, "c")
    rootVbox:addWidget(titleText, 1)

    local headerHBox = container.hBox()
    local headerBox = container.framedBox(headerHBox)
    rootVbox:addWidget(headerBox, 3)
    local pathText = tui.textWidget(path, "l")
    headerHBox:addWidget(pathText)
    local updatePath

    ---@param theme table
    ---@return string
    ---@return string
    ---@return string
    local function folderIcon(theme)
        return "\x83\x94", "14", "4" .. colors.toBlit(theme.bg)
    end
    ---@param theme table
    ---@param luafile boolean?
    ---@return string
    ---@return string
    ---@return string
    local function itemIcon(theme, luafile)
        local col = colors.toBlit(theme.inputbg)
        if theme.bg == colors.black then
            col = colors.toBlit(theme.fg)
        end
        if luafile then
            col = colors.toBlit(colors.blue)
        end
        return "\x82", colors.toBlit(theme.bg), col
    end

    ---@param onPress fun(self:ButtonWidget)
    ---@param icon fun(theme:table):string,string,string
    ---@return ButtonWidget
    local function buttonIcon(onPress, icon)
        local button = input.buttonWidget("", onPress, nil, false, "c")
        button.draw = function(self)
            draw.set_col(self.theme.fg, self.theme.bg, self.window)
            self.window.clear()
            draw.text(1, 1, "+", self.window)
            self.window.blit(icon(self.theme))
        end
        return button
    end

    ---@type string?
    local selectedFile

    local function overwritePopup(path)
        return confirmationPopup("Overwrite File?", ("This will overwrite the file:\n%s\nAre you sure?"):format(path))
    end

    local fileList = list.listWidget(fs.list(path), 1, function(win, x, y, w, h, item, theme)
        win.setCursorPos(x, y)
        draw.set_col(theme.fg, theme.bg, win)
        if fs.isDir(fs.combine(path, item)) then
            win.blit(folderIcon(theme))
            draw.set_col(theme.highlight, nil, win)
        else
            win.blit(itemIcon(theme, item:sub(-4) == ".lua"))
        end
        draw.text(x + 2, y, item, win)
    end, function(index, item)
        local filePath = fs.combine(path, item)
        if fs.isDir(filePath) then
            updatePath(filePath)
        elseif not write or overwritePopup(filePath) then
            rootBox.exit = true
            selectedFile = filePath
        end
    end, function(index, item)
        local filePath = fs.combine(path, item)
        local isDir = fs.isDir(filePath)
        if isDir and not allowDirs then
            return
        end
        if isDir or not write or overwritePopup(filePath) then
            rootBox.exit = true
            selectedFile = filePath
        end
    end)
    local fileBox = container.framedBox(fileList)
    rootVbox:addWidget(fileBox)

    if allowDirs or write then
        -- newfileHbox = container.hBox()
        -- rootVbox:addWidget(newfileHbox, 1)
        local newfolderButton = buttonIcon(function(self)
            local foldername = inputPopup("New Folder", ("At path %s"):format(path), "Name")
            if foldername then
                local newpath = fs.combine(path, foldername)
                fs.makeDir(newpath)
                updatePath(newpath)
            end
        end, folderIcon)
        headerHBox:addWidget(newfolderButton, 4)
    end
    if write then
        local newfileButton = buttonIcon(function(self)
            local filename = inputPopup("New File", ("At path %s"):format(path), "Name")
            if filename then
                tui.quit(rootBox)
                if extension and not (filename:sub(- #extension) == extension) then
                    -- extension required and currently not in the filename
                    filename = ("%s.%s"):format(filename, extension)
                end
                selectedFile = fs.combine(path, filename)
            end
        end, itemIcon)
        headerHBox:addWidget(newfileButton, 4)
    end

    function updatePath(newPath)
        if not fs.exists(newPath) then
            return
        end
        path = newPath
        local files_raw = fs.list(path)
        local files_filtered = {}
        for i, v in ipairs(files_raw) do
            if fs.isDir(fs.combine(path, v)) then
                files_filtered[#files_filtered + 1] = v .. "/"
            elseif (not extension) or v:sub(- #extension) == extension then
                files_filtered[#files_filtered + 1] = v
            end
        end
        if path == "" then path = "/" end
        if path ~= "/" then
            table.insert(files_filtered, 1, "..")
        end
        fileList:setTable(files_filtered)
        pathText:updateText(path)
    end

    updatePath(path)

    tui.run(rootBox, not mandatory, function(event)
        if event == "back_button" then
            if mandatory and (path == "" or path == "/") then
                -- already at the root
                rootBox.exit = true
            end
            updatePath(fs.combine(path, ".."))
        end
    end, true)

    return selectedFile
end

return {
    listPopup = listPopup,
    filePopup = filePopup,
    confirmationPopup = confirmationPopup,
    inputPopup = inputPopup
}
