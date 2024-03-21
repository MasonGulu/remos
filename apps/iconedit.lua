local draw = require "draw"

local termW, termH = term.getSize()
local win = window.create(term.current(), 1, 1, termW, termH)

---Load an icon
---@param fn any
---@return BLIT?
---@return string?
local function loadIcon(fn)
    local icon, reason = remos.loadTable(fn)
    return icon --[[@as BLIT]]
end

---Apply transparency to a clone of the given blit table
---@param blit BLIT
---@param color color
---@return BLIT
local function resolveTransparency(blit, color)
    local bgchar = colors.toBlit(color)
    blit = remos.deepClone(blit)
    for _, v in ipairs(blit) do
        v[2] = string.gsub(v[2], " ", bgchar)
        v[3] = string.gsub(v[3], " ", bgchar)
    end
    return blit
end

---@type table<integer,table<integer,string>> [y][x]
local clickableCharacterPositions = {}
---@type table<string,{x:integer,y:integer}>
local characterPositions = {}

---@param x integer
---@param y integer
---@param c integer
---@param width integer
---@return integer
---@return integer
local function getCharacterPos(x, y, c, width)
    return x + (c % width) + 1, y + math.floor(c / width) + 1
end

local selectedCharacter = "\0"
local selectedFg, selectedBg = colors.white, -1
local themeFg, themeBg = colors.white, colors.black

---Apply transparency
---@param fg number
---@param bg number
---@return number
---@return number
local function applyTransparency(fg, bg)
    return fg == -1 and themeBg or fg, bg == -1 and themeBg or bg
end

---@param x integer
---@param y integer
---@param width integer
local function drawCharacters(x, y, width)
    draw.square(x, y, width + 2, math.ceil(255 / width) + 2, win)
    clickableCharacterPositions = {}
    characterPositions = {}
    for c = 0, 255 do
        local cx, cy = getCharacterPos(x, y, c, width)
        clickableCharacterPositions[cy] = clickableCharacterPositions[cy] or {}
        local ch = string.char(c)
        clickableCharacterPositions[cy][cx] = ch
        characterPositions[ch] = { x = cx, y = cy }
        local fg, bg = applyTransparency(selectedFg, selectedBg)
        draw.set_col(fg, bg, win)
        draw.text(cx, cy, ch, win)
    end
end

---@param x integer
---@param y integer
---@return string?
local function decodeCharacter(x, y)
    if clickableCharacterPositions[y] then
        return clickableCharacterPositions[y][x]
    end
end

local function moveCursorToSelectedChar()
    win.setCursorBlink(true)
    local pos = characterPositions[selectedCharacter]
    win.setCursorPos(pos.x, pos.y)
end

---@type table<integer,table<integer,integer>> [y][x]
local clickableColorPositions = {}
local function drawColors(x, y, width)
    draw.set_col(colors.white, colors.black, win)
    draw.square(x, y, width + 2, math.ceil(17 / width) + 2, win)
    clickableColorPositions = {}
    for i = 0, 16 do
        local cx, cy = getCharacterPos(x, y, i, width)
        clickableColorPositions[cy] = clickableColorPositions[cy] or {}
        if i == 16 then
            draw.set_col(themeFg, themeBg, win)
            draw.text(cx, cy, "T", win)
            clickableColorPositions[cy][cx] = -1
        else
            draw.set_col(colors.white, 2 ^ i, win)
            draw.text(cx, cy, " ", win)
            clickableColorPositions[cy][cx] = 2 ^ i
        end
    end
    draw.set_col(colors.white, colors.black, win)
end

---@param x integer
---@param y integer
---@return integer?
local function decodeColor(x, y)
    if clickableColorPositions[y] then
        return clickableColorPositions[y][x]
    end
end

local imagew, imageh = 4, 3
local charsx, charsy = imagew + 2, 1

local image = loadIcon("icons/default_icon_small.blit") --[[@as BLIT]]

local function setChar(x, y)
    local bg = selectedBg == -1 and " " or colors.toBlit(selectedBg)
    local fg = selectedFg == -1 and " " or colors.toBlit(selectedFg)
    image[y][1] = image[y][1]:sub(1, x - 1) .. selectedCharacter .. image[y][1]:sub(x + 1, -1)
    image[y][2] = image[y][2]:sub(1, x - 1) .. fg .. image[y][2]:sub(x + 1, -1)
    image[y][3] = image[y][3]:sub(1, x - 1) .. bg .. image[y][3]:sub(x + 1, -1)
end

local function generateImage()
    image = {}
    for y = 1, imageh do
        image[y] = {}
        local str = (" "):rep(imagew)
        image[y][1] = str
        image[y][2] = str
        image[y][3] = str
    end
end

while true do
    win.setVisible(false)
    draw.set_col(colors.white, colors.black, win)
    win.clear()
    draw.square(1, 1, imagew + 2, imageh + 2, win)
    draw.draw_blit(2, 2, resolveTransparency(image, themeBg), win)
    drawCharacters(charsx, charsy, termW - imagew - 3)
    drawColors(1, imageh + 3, imagew - 1)
    draw.text(1, termH, "[S]ave [O]pen [T]heme [N]ew", win)
    moveCursorToSelectedChar()
    win.setVisible(true)
    local e = { os.pullEvent() }
    if e[1] == "mouse_click" then
        local x, y = e[3], e[4]
        local ch = decodeCharacter(x, y)
        local col = decodeColor(x, y)
        if ch then
            selectedCharacter = ch
        elseif col then
            if e[2] == 1 then
                selectedFg = col
            elseif e[2] == 2 then
                selectedBg = col
            end
        elseif x > 1 and x < imagew + 2 and y > 1 and y < imageh + 2 then
            x, y = x - 1, y - 1
            setChar(x, y)
        end
    elseif e[1] == "char" then
        local ch = e[2]
        if ch == "t" then
            themeFg, themeBg = themeBg, themeFg
        elseif ch == "o" then
            local popups = require "touchui.popups"
            local f = popups.filePopup("Open file", "", false, false, false, "blit")
            if f then
                local icon = loadIcon(f)
                if icon then
                    imageh = #icon
                    imagew = #icon[1][1]
                    charsx, charsy = imagew + 2, 1
                    image = icon
                end
            end
        elseif ch == "s" then
            local popups = require "touchui.popups"
            local f = popups.filePopup("Save file", "", false, true, false, "blit")
            if f then
                remos.saveTable(f, image)
            end
        elseif ch == "n" then
            local popups = require "touchui.popups"
            local ok = popups.confirmationPopup("Create a new file?", "You will lose your current file.")
            if ok then
                local _, size = popups.listPopup("What size of icon?", { "Large", "Small" }, 1,
                    function(win, x, y, w, h, item, theme)
                        draw.text(x, y, item, win)
                    end)
                if size == "Large" then
                    imagew, imageh = 7, 4
                else
                    imagew, imageh = 4, 3
                end
                charsx, charsy = imagew + 2, 1
                generateImage()
            end
        end
    end
end
