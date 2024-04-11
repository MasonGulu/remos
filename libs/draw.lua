local win = term --[[@as Window|term]]

---@param v0 number
---@param v1 number
---@param t number
---@return number
local function lerp(v0, v1, t)
    return v0 + t * (v1 - v0)
end

---@param p0 number
---@param p1 number
---@param p2 number
---@param t number
---@return number
local function quad_curve(p0, p1, p2, t)
    return lerp(lerp(p0, p1, t), lerp(p1, p2, t), t)
end

local function cubic_curve(p0, p1, p2, p3, t)
    return ((1 - t) * quad_curve(p0, p1, p2, t)) + (t * quad_curve(p1, p2, p3, t))
end

local function get_slope_char(slope)
    if slope > 2 then
        return "|"
    elseif slope >= 0.5 then
        return "\\"
    elseif slope >= -0.5 then
        return "-"
    elseif slope > -2 then
        return "/"
    end
    return "|"
end

---setCursorPos shortcut
---@param x integer
---@param y integer
---@param t string
---@param dev Window|term
---@param size integer? >0 for bigfont
local function text(x, y, t, dev, size)
    dev = dev or win
    size = size or 0
    dev.setCursorPos(x, y)
    if size > 0 then
        local bigfont = require "bigfont"
        bigfont.writeOn(dev, size, t, x, y)
    else
        dev.write(t)
    end
end

---@param y integer
---@param t string
---@param dev Window|term
---@param size integer? >0 for bigfont
local function center_text(y, t, dev, size)
    dev = dev or win
    size = size or 0
    local w = dev.getSize()
    local tsize = #t
    if size > 0 then
        tsize = tsize * 3 * size
    end
    text(math.ceil((w - tsize) / 2), y, t, dev, size)
end

---@param dev Window|term
---@return integer
---@return integer
local function get_pos(dev)
    dev = dev or win
    return dev.getCursorPos()
end

---@param dev Window|term
---@return color fg
---@return color bg
local function get_col(dev)
    dev = dev or win
    return dev.getTextColor(), dev.getBackgroundColor()
end

---@param fg color?
---@param bg color?
---@param dev Window|term
local function set_col(fg, bg, dev)
    dev = dev or win
    if fg then
        dev.setTextColor(fg)
    end
    if bg then
        dev.setBackgroundColor(bg)
    end
end


---Draw a line between two points
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param device Window|term
---@param ch string?
local function line(x1, y1, x2, y2, device, ch)
    device = device or win
    ch = ch or get_slope_char((y2 - y1) / (x2 - x1))
    local line_length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    for t = 0, 1, 1 / line_length do
        local x = lerp(x1, x2, t)
        local y = lerp(y1, y2, t)
        text(x, y, ch, device)
    end
end

local function clamp(x, lower, upper)
    lower = lower or 0
    upper = upper or 1
    if x < lower then return lower end
    if x > upper then return upper end
    return x
end

local function smooth_step(x, edge0, edge1)
    edge0 = edge0 or 0
    edge1 = edge1 or 1
    x = clamp((x - edge0) / (edge1 - edge0))

    return x * x * x * (3 * x * (2 * x - 5) + 10)
end

---@param ... integer
---@return integer
local function round(...)
    local r = {}
    for i, v in ipairs({ ... }) do
        r[i] = math.floor(v + 0.5)
    end
    return table.unpack(r)
end

local function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end
---Draw a line between two points
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param device Window|term
---@param ch string?
local function smooth_step_line(x1, y1, x2, y2, device, ch)
    device = device or win
    local line_length = distance(x1, y1, x2, y2)
    local function get_xy(t)
        local x = lerp(x1, x2, t)
        local y = y1 + (smooth_step(t) * (y2 - y1))
        return x, y
    end
    local ox, oy = x1, y1
    local interval = 0.5 / line_length
    for t = 0, 1, interval do
        local x, y = round(get_xy(t))
        local nx, ny = get_xy(t + interval)
        text(x, y, ch or get_slope_char((ny - oy) / (nx - ox)), device)
        ox, oy = x, y
    end
end

---Draw a line between two points
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param x3 integer
---@param y3 integer
---@param device Window|term
---@param ch string?
local function quad_line(x1, y1, x2, y2, x3, y3, device, ch)
    device = device or win
    local line_length = distance(x1, y1, x2, y2) + distance(x2, y2, x3, y3)
    local function get_xy(t)
        local x = quad_curve(x1, x2, x3, t)
        local y = quad_curve(y1, y2, y3, t)
        return x, y
    end
    local ox, oy = x1, y1
    local interval = 1 / line_length
    for t = 0, 1, interval do
        local x, y = round(get_xy(t))
        local nx, ny = get_xy(t + interval)
        text(x, y, ch or get_slope_char((ny - oy) / (nx - ox)), device)
        ox, oy = x, y
    end
end


---Draw a line between two points
---@param x1 integer
---@param y1 integer
---@param x2 integer
---@param y2 integer
---@param x3 integer
---@param y3 integer
---@param x4 integer
---@param y4 integer
---@param device Window|term
---@param ch string?
local function cubic_line(x1, y1, x2, y2, x3, y3, x4, y4, device, ch)
    device = device or win
    -- local chord = distance(x1, y1, x4, y4)
    local cont_net = distance(x1, y1, x2, y2) + distance(x2, y2, x3, y3) + distance(x3, y3, x4, y4)
    local line_length = 0.8 * cont_net
    local function get_xy(t)
        local x = cubic_curve(x1, x2, x3, x4, t)
        local y = cubic_curve(y1, y2, y3, y4, t)
        return x, y
    end
    local ox, oy = x1, y1
    local interval = 0.5 / line_length
    for t = 0, 1, interval do
        local x, y = get_xy(t)
        local r_x, r_y = round(x, y)
        local nx, ny = get_xy(t + interval)
        text(r_x, r_y, ch or get_slope_char((ny - oy) / (nx - ox)), device)
        ox, oy = x, y
    end
end

---Draw a cubic line aligned with the y axis
---@param x1 integer input
---@param y1 integer input
---@param x4 integer output
---@param y4 integer output
---@param device Window|term
---@param ch string?
local function aligned_cubic_line(x1, y1, x4, y4, device, ch)
    local x2, x3, y2, y3
    local offset = round(clamp(0.5 * math.abs(x1 - x4), 10, 30))
    local y_offset = round(clamp(0.5 * math.abs(y1 - y4), 0, 30))
    if y1 > y4 then
        y_offset = -y_offset
    end
    x2 = x1 + offset
    y2 = y1 + y_offset
    x3 = x4 - offset
    y3 = y4 - y_offset
    cubic_line(x1, y1, x2, y2, x3, y3, x4, y4, device, ch)
end

---@param device Window|term
local function invert(device)
    local fg, bg = get_col(device)
    set_col(bg, fg, device)
end


---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param ch string? box side override
---@param dev Window|term
local function square(x, y, w, h, dev, ch)
    local topl = ch or string.char(0x97) -- normal
    local topr = ch or string.char(0x94)
    local top  = ch or string.char(0x83)
    local side = ch or string.char(0x95) -- both (l/r)
    local botl = ch or string.char(0x8a) -- inverse
    local bot  = ch or string.char(0x8f)
    local botr = ch or string.char(0x85)
    if not dev then dev = win end -- formatter kept aligning assignment here.
    text(x, y, topl, dev)
    text(x + 1, y, top:rep(w - 2), dev)
    for dy = 1, h - 2 do
        text(x, y + dy, side, dev)
    end
    if not ch then
        invert(dev)
    end
    text(x + w - 1, y, topr, dev)
    text(x, y + h - 1, botl, dev)
    text(x + 1, y + h - 1, bot:rep(w - 2), dev)
    text(x + w - 1, y + h - 1, botr, dev)
    for dy = 1, h - 2 do
        text(x + w - 1, y + dy, side, dev)
    end
    if not ch then
        invert(dev)
    end
end

---@alias BLIT {[1]:string,[2]:string,[3]:string}[]

---@param x integer
---@param y integer
---@param img BLIT
---@param dev Window|term
local function draw_blit(x, y, img, dev)
    for i = 1, #img do
        dev.setCursorPos(x, y + i - 1)
        dev.blit(table.unpack(img[i]))
    end
end

---@param y integer
---@param dev Window|term
local function clear_line(y, dev)
    dev.setCursorPos(1, y)
    dev.clearLine()
end

return {
    line = line,
    aligned_cubic_line = aligned_cubic_line,
    cubic_line = cubic_line,
    quad_line = quad_line,
    smooth_step_line = smooth_step_line,
    ---@param new_win Window|term
    set_default = function(new_win)
        win = new_win
    end,
    round = round,
    text = text,
    get_col = get_col,
    get_pos = get_pos,
    invert = invert,
    square = square,
    set_col = set_col,
    center_text = center_text,
    draw_blit = draw_blit,
    clear_line = clear_line
}
