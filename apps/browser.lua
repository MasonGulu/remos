-- File browser
local tui = require("touchui")
local container = require("touchui.containers")
local input = require("touchui.input")
local rootWin = window.create(term.current(), 1, 1, term.getSize())
local list = require("touchui.lists")
local popups = require("touchui.popups")
local draw = require("draw")

remos.setTitle("Browser")


local path = ({ ... })[1] or ""

local function fileMenu(filePath)
    local fileOptions = {
        "Delete",
        "Move",
        "Copy"
    }
    if not fs.isDir(filePath) then
        table.insert(fileOptions, 1, "Edit")
        table.insert(fileOptions, 1, "Run")
    end

    local label = "File Options"
    local attributes = fs.attributes(filePath)
    local attributeVbox = container.vBox()

    attributeVbox:addWidget(tui.textWidget(("Path: %s"):format(filePath), "l"), 2)
    attributeVbox:addWidget(tui.textWidget(("Size: %d bytes"):format(attributes.size), "l"), 1)
    attributeVbox:addWidget(tui.textWidget(("Created: %s"):format(os.date("%D %T", attributes.created)), "l"), 2)
    attributeVbox:addWidget(tui.textWidget(("Modified: %s"):format(os.date("%D %T", attributes.modified)), "l"), 2)

    local i, item = popups.listPopup(label, fileOptions, 1, function(win, x, y, w, h, item, theme)
        draw.text(x, y, item, win)
    end, attributeVbox)
    if item then
        if item == "Run" then
            remos.addAppFile(filePath)
        elseif item == "Edit" then
            remos.addAppFile("/rom/programs/edit.lua", filePath)
        elseif item == "Delete" and popups.confirmationPopup(("Delete %s?"):format(filePath), "Are you sure you want to delete this file?") then
            fs.delete(filePath)
        elseif item == "Move" then
            local to = popups.filePopup(("Move %s to?"):format(filePath), nil, false, true, true)
            if to then
                local from = filePath
                if not fs.isDir(from) and fs.isDir(to) then
                    -- moving a file to a folder, move it *into* the folder instead
                    to = fs.combine(to, fs.getName(filePath))
                end
                fs.move(from, to)
            end
        elseif item == "Copy" then
            local to = popups.filePopup(("Copy %s to?"):format(filePath), nil, false, true, true)
            if to then
                local from = filePath
                if not fs.isDir(from) and fs.isDir(to) then
                    -- moving a file to a folder, move it *into* the folder instead
                    to = fs.combine(to, fs.getName(filePath))
                end
                fs.copy(from, to)
            end
        end
    end
end

while true do
    local file = popups.filePopup("Browser", path, true, nil, true, nil, -1)
    if file then
        fileMenu(file)
        path = file:sub(1, -(#fs.getName(file) + 1))
    end
end
