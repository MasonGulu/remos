local tui = require("touchui")
local container = require("touchui.containers")
local list = require("touchui.lists")
local draw = require("touchui.draw")
local input = require("touchui.input")
local homeWin = window.create(term.current(), 1, 1, term.getSize())

local hBox = container.scrollableHBox()
hBox:setWindow(homeWin)
local vBox = container.vBox()
---@alias TaskMonFieldInfo {format:string,title:string,key:string,formatList:string,floatFix:boolean?,width:integer}
---@type TaskMonFieldInfo[]
local fields = {}
local function addField(width, title, key, formatList, floatFix)
    local format = ("%%%ds"):format(width)
    fields[#fields + 1] = {
        format = format,
        width = width,
        title = title,
        key = key,
        formatList = formatList or format,
        floatFix = floatFix
    }
end
local sortField = "pid"
local sortDir = true
addField(-20, "Title", "title", "%-20s")
addField(5, "pid", "pid", "%5d")
addField(5, "ppid", "ppid", "%5d")
addField(11, "State", "state", "%11s")
addField(9, "Mean ms", "meanExeTime", "%.3f", true)
addField(9, "Last ms", "lastExeTime", "%9d")
addField(9, "Total ms", "totalExeTime", "%9d")
addField(7, "Cycles", "cyclesAlive", "%7d")
local headerStr = ""
local ccstrings = require "cc.strings"
---@param item Process
local function getListStr(item)
    local listStr = ""
    for _, v in ipairs(fields) do
        local listVal = item[v.key]
        if type(listVal) == "string" then
            listVal = ccstrings.ensure_width(listVal, math.abs(v.width))
        end
        local s = v.formatList:format(listVal)
        if v.floatFix then
            s = v.format:format(s)
        end
        listStr = listStr .. s .. "\149"
    end
    return listStr
end
for _, v in ipairs(fields) do
    local label = v.format:format(v.title) .. "\149"
    headerStr = headerStr .. label
end
hBox:addWidget(vBox, #headerStr)
local header = container.hBox()
vBox:addWidget(header, 1)
local buttons = {}

---@param v TaskMonFieldInfo
local function updateSortField(v)
    if sortField then
        local sortButton = buttons[sortField]
        local field = fields[sortField]
        sortButton.label = field.format:format(field.title) .. "\149"
    end
    if sortField == v.key then
        sortDir = not sortDir
    end
    sortField = v.key
    buttons[sortField].label = v.format:format(v.title .. (sortDir and "\24" or "\25")) .. "\149"
end
for i, v in ipairs(fields) do
    local label = v.format:format(v.title) .. "\149"
    local button = input.buttonWidget(label, function(self)
        updateSortField(v)
    end, nil, false, "l")
    buttons[v.key] = button
    fields[v.key] = v
    header:addWidget(button, math.abs(v.width) + 1)
end
updateSortField(fields[2])

local sortedProcesses = {}
local inbox = list.listWidget(sortedProcesses, 1, function(win, x, y, w, h, item, theme)
    draw.text(x, y, getListStr(item), win)
end)
vBox:addWidget(inbox)

local function updateProccesses()
    sortedProcesses = {}
    for pid, process in pairs(remos._processes) do
        sortedProcesses[#sortedProcesses + 1] = process
    end
    table.sort(sortedProcesses, function(a, b)
        local res = a[sortField] < b[sortField]
        if sortDir then
            return not res
        end
        return res
    end)
    inbox:setTable(sortedProcesses)
end
updateProccesses()


parallel.waitForAny(function() tui.run(hBox) end, function()
    while true do
        sleep(1)
        updateProccesses()
    end
end)
