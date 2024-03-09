-- File browser
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local rootWin = window.create(term.current(), 1, 1, term.getSize())
local list = require("touchui.lists")
local popups = require("touchui.popups")
local draw = require("touchui.draw")

local path = "/"

remos.setTitle("Browser - " .. path)

local rootVbox = container.vBox()
rootVbox:setWindow(rootWin)

local pathText = tui.textWidget(path, "c")
rootVbox:addWidget(pathText, 1)

local fileOptions = {
    "Run",
    "Edit"
}

local updatePath
local function fileMenu(filePath)
    local label = "File Options"
    local attributes = fs.attributes(filePath)
    local attributeVbox = container.vBox()
    attributeVbox:addWidget(tui.textWidget(("Path: %s"):format(filePath), "l"))
    attributeVbox:addWidget(tui.textWidget(("Size: %d bytes"):format(attributes.size), "l"))
    attributeVbox:addWidget(tui.textWidget(("Created: %s"):format(os.date("%D %T", attributes.created)), "l"))
    attributeVbox:addWidget(tui.textWidget(("Modified: %s"):format(os.date("%D %T", attributes.modified)), "l"))

    local i, item = popups.listPopup(label, fileOptions, 1, function(win, x, y, w, h, item, theme)
        draw.text(x, y, item, win)
    end, attributeVbox)
    if item then
        if item == "Run" then
            remos.addAppFile(filePath)
        elseif item == "Edit" then
            remos.addAppFile("/rom/programs/edit.lua", filePath)
        end
    end
end

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
        fileMenu(filePath)
    end
end, function(index, item)
    local filePath = fs.combine(path, item)
    fileMenu(filePath)
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
    remos.setTitle("Browser - " .. path)
end

updatePath(path)

tui.run(rootVbox, nil, function(event)
    if event == "backButton" then
        updatePath(fs.combine(path, ".."))
    end
end)
