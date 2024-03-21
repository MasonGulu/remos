local termw, termh = term.getSize()
local rootWin = window.create(term.current(), 1, 1, termw, termh)
local boardw, boardh = 100, 100
local draw

local scrollX, scrollY = 0, 0

---@type string[][]
local snakeTrails = {}
---@type string[][]
local claimedLand = {}
---@type table<string,Player>
local players = {}

local dirs = {}
dirs.up = vector.new(0, -1, 0)
dirs.left = vector.new(-1, 0, 0)
dirs.right = vector.new(1, 0, 0)
dirs.down = vector.new(0, 1, 0)

local oppositeDirs = {}
oppositeDirs.up = dirs.down
oppositeDirs.down = dirs.up
oppositeDirs.left = dirs.right
oppositeDirs.right = dirs.left

---@generic T
---@param t T[][]
---@param v T
local function initArray(t, v)
    for y = 1, boardh do
        t[y] = {}
        for x = 1, boardw do
            t[y][x] = v
        end
    end
end

---Remove an element from an array
---@generic T:any
---@param t T[]
---@param v T
---@return boolean success
local function removeFromArray(t, v)
    for i, v2 in pairs(t) do
        if v == v2 then
            table.remove(t, i)
            return true
        end
    end
    return false
end

local function resetGame()
    initArray(snakeTrails, " ")
    initArray(claimedLand, " ")
    players = {}
end
resetGame()

---@class Player
---@field pos Vector
---@field vel Vector
---@field lastAppliedVel Vector
---@field color string
---@field alive boolean
---@field drawing boolean whether the snake is currently claiming new terrain
---@field char string
---@field name string

---Set a value at a position in a 2d table
---@generic T : any
---@param t T[][]
---@param pos Vector
---@param value T
local function set(t, pos, value)
    if pos.y < 1 or pos.y > #t or pos.x < 1 or pos.x > #t[pos.y] then
        return
    end
    t[pos.y][pos.x] = value
end

---Get a value from a position in a 2d table
---@generic T : any
---@param t T[][]
---@param pos Vector
---@return T
local function get(t, pos)
    if pos.y < 1 or pos.y > #t or pos.x < 1 or pos.x > #t[pos.y] then
        return nil
    end
    return t[pos.y][pos.x]
end

local possibleChars = { "\1", "\2", "\3", "\4", "\5", "\6", "\11", "\12", "\14", "\15", "\169", "\207" }
local function getRandomChar()
    return possibleChars[math.random(1, #possibleChars)]
end

local function getSpawnPosition()
    local vec
    local isValid = false
    repeat
        local x, y = math.random(2, boardw - 1), math.random(2, boardh - 1)
        vec = vector.new(x, y, 0)
        isValid = true
        for dx = -3, 3 do
            for dy = -3, 3 do
                if get(snakeTrails, vec + vector.new(dx, dy, 0)) ~= " " then
                    isValid = false
                    break
                end
            end
        end
    until isValid
    return vec
end

---@param name string
---@return Player
local function newPlayer(c, name)
    assert(not players[c], "Attempt to add player with used color")
    local pos = getSpawnPosition()
    ---@type Player
    local player = {
        pos = pos,
        vel = vector.new(0, 0, 0),
        lastAppliedVel = vector.new(0, 0, 0),
        color = c,
        alive = true,
        drawing = false,
        fillPoints = {},
        char = getRandomChar(),
        name = name
    }
    for dx = -1, 1 do
        for dy = -1, 1 do
            set(claimedLand, pos + vector.new(dx, dy, 0), c)
        end
    end
    players[c] = player
    return player
end

---Iterate over the entire array
---@generic T
---@param t T[][]
---@param func fun(x:integer,y:integer,val:T)
local function iterate(t, func)
    for y, line in ipairs(t) do
        for x, val in ipairs(line) do
            func(x, y, val)
        end
    end
end

---@param player Player
---@param killer Player?
local function killPlayer(player, killer)
    if not player then return end
    local replacementColor = " "
    if killer then
        replacementColor = killer.color
    end
    player.alive = false
    iterate(claimedLand, function(x, y, val)
        if val == player.color then
            claimedLand[y][x] = replacementColor
        end
    end)
    iterate(snakeTrails, function(x, y, val)
        if val == player.color then
            snakeTrails[y][x] = " "
        end
    end)
    players[player.color] = nil
    -- error("You died!")
end

local tempFill = {}
initArray(tempFill, " ")
---@param player Player
---@param x integer
---@param y integer
---@return "claimed"|"inside"|"oob"
local function inside(player, x, y)
    if y < 1 or y > boardh or x < 1 or x > boardw then
        return "oob"
    end
    assert(claimedLand[y], y)
    local isClaimed = claimedLand[y][x] == player.color or tempFill[y][x] == player.color
    return isClaimed and "claimed" or "inside" -- and snakeTrails[y][x] ~= player.color
end

local function insideBool(player, x, y)
    return inside(player, x, y) == "inside"
end

local function createStack()
    local stack = {}
    return {
        push = function(v)
            stack[#stack + 1] = v
        end,
        pop = function()
            return table.remove(stack, 1)
        end,
        len = function()
            return #stack
        end
    }
end

local territoryKill = true

---Used by fill to set each point in the fill region
---Checks for players at the space, kills them if one is there
local function setSpace(y, x, color)
    claimedLand[y][x] = color
    if territoryKill then
        for c, player in pairs(players) do
            if c ~= color then
                if player.pos:equals(vector.new(x, y, 0)) then
                    killPlayer(player, players[color])
                end
            end
        end
    end
end

---@param player Player
---@param pos Vector
local function fill(player, pos)
    initArray(tempFill, " ")
    if not insideBool(player, pos.x, pos.y) then return end
    local stack = createStack()
    stack.push(pos.x)
    stack.push(pos.x)
    stack.push(pos.y)
    stack.push(1)

    stack.push(pos.x)
    stack.push(pos.x)
    stack.push(pos.y - 1)
    stack.push(-1)
    while stack.len() > 0 do
        local x1 = stack.pop()
        local x2 = stack.pop()
        local y = stack.pop()
        local dy = stack.pop()
        local x = x1
        if insideBool(player, x, y) then
            while insideBool(player, x - 1, y) do
                setSpace(y, x - 1, player.color)
                x = x - 1
            end
            if x < x1 then
                stack.push(x)
                stack.push(x1 - 1)
                stack.push(y - dy)
                stack.push(-dy)
            end
        end
        while x1 <= x2 do
            while insideBool(player, x1, y) do
                setSpace(y, x1, player.color)
                x1 = x1 + 1
            end
            if x1 > x then
                stack.push(x)
                stack.push(x1 - 1)
                stack.push(y + dy)
                stack.push(dy)
            end
            if x1 - 1 > x2 then
                stack.push(x2 + 1)
                stack.push(x1 - 1)
                stack.push(y - dy)
                stack.push(-dy)
            end
            x1 = x1 + 1
            while x1 < x2 and not insideBool(player, x1, y) do
                x1 = x1 + 1
            end
            x = x1
        end
    end
end

---Check if this point is within the snake's boundaries
---@param player Player
---@param pos Vector
---@return boolean
local function isInsideSnake(player, pos)
    initArray(tempFill, " ")
    if not insideBool(player, pos.x, pos.y) then return false end
    local stack = createStack()
    stack.push(pos.x)
    stack.push(pos.x)
    stack.push(pos.y)
    stack.push(1)

    stack.push(pos.x)
    stack.push(pos.x)
    stack.push(pos.y - 1)
    stack.push(-1)
    while stack.len() > 0 do
        local x1 = stack.pop()
        local x2 = stack.pop()
        local y = stack.pop()
        local dy = stack.pop()
        local x = x1
        if insideBool(player, x, y) then
            while insideBool(player, x - 1, y) do
                tempFill[y][x - 1] = player.color
                x = x - 1
            end
            if inside(player, x, y) == "oob" then
                return false
            end
            if x < x1 then
                stack.push(x)
                stack.push(x1 - 1)
                stack.push(y - dy)
                stack.push(-dy)
            end
        elseif inside(player, x, y) == "oob" then
            return false
        end
        while x1 <= x2 do
            while insideBool(player, x1, y) do
                tempFill[y][x1] = player.color
                x1 = x1 + 1
            end
            if inside(player, x1, y) == "oob" then
                return false
            end
            if x1 > x then
                stack.push(x)
                stack.push(x1 - 1)
                stack.push(y + dy)
                stack.push(dy)
            end
            if x1 - 1 > x2 then
                stack.push(x2 + 1)
                stack.push(x1 - 1)
                stack.push(y - dy)
                stack.push(-dy)
            end
            x1 = x1 + 1
            while x1 < x2 and not insideBool(player, x1, y) do
                x1 = x1 + 1
            end
            x = x1
        end
    end
    return true
end

---Traverse the tail of a given player
---@param player Player
local function completeTailLoop(player)
    local emptySpaces = {}
    local function iteratePoint(pos)
        if get(snakeTrails, pos) ~= player.color then
            return get(claimedLand, pos) ~= player.color -- empty space
        end
        set(claimedLand, pos, player.color)
        set(snakeTrails, pos, " ")
        for _, dir in pairs(dirs) do
            local newpos = pos + dir
            if iteratePoint(newpos) then
                -- term.setCursorPos(newpos.x, newpos.y)
                -- term.write("!")
                -- sleep(0.2)
                emptySpaces[#emptySpaces + 1] = newpos
            end
        end
    end
    iteratePoint(player.pos - player.lastAppliedVel)
    for _, point in ipairs(emptySpaces) do
        if isInsideSnake(player, point) then
            fill(player, point)
            break
        end
    end
end

---@alias LandOwnership {color:string,percentage:number}

---@type LandOwnership[]
local landOwnershipTable = {}
local function recomputeLand()
    local totalLand = boardh * boardw
    landOwnershipTable = {}
    ---@type table<string,integer>
    local landOwnershipTotal = {}
    iterate(claimedLand, function(x, y, val)
        if val == " " then return end
        landOwnershipTotal[val] = (landOwnershipTotal[val] or 0) + 1
    end)
    for color, total in pairs(landOwnershipTotal) do
        landOwnershipTable[#landOwnershipTable + 1] = { color = color, percentage = total / totalLand }
    end
    table.sort(landOwnershipTable, function(a, b)
        return a.percentage > b.percentage
    end)
end

---@param player Player
---@return boolean? died
local function tickPlayer(player)
    if not player.alive then
        return true
    end
    if vector.new(0, 0, 0):equals(player.vel) then
        return -- player is not yet moving
    end
    player.pos = player.pos + player.vel
    player.lastAppliedVel = player.vel
    if player.pos.x < 1 or player.pos.x > boardw or player.pos.y < 1 or player.pos.y > boardh then
        killPlayer(player)
        recomputeLand()
        return true
    end
    local hittingSnakeTrail = get(snakeTrails, player.pos)
    local hittingClaimedLand = get(claimedLand, player.pos)
    if hittingSnakeTrail ~= " " then
        if hittingSnakeTrail == player.color then
            -- hitting own trail
            killPlayer(player)
            recomputeLand()
            return true
        else
            killPlayer(players[hittingSnakeTrail], player)
            recomputeLand()
        end
    end
    if hittingClaimedLand == player.color then
        -- Hitting our own land
        if player.drawing then
            completeTailLoop(player)
            recomputeLand()
        end
        player.drawing = false
    else
        player.drawing = true
        set(snakeTrails, player.pos, player.color)
    end
end

local function blitAt(x, y, text, fg, bg)
    if x < 1 or y < 1 or x > termw or y > termh then
        return
    end
    rootWin.setCursorPos(x, y)
    rootWin.blit(text, fg, bg)
end

local function drawField()
    iterate(claimedLand, function(x, y, val)
        if val ~= " " then
            blitAt(x - scrollX, y - scrollY, " ", "f", val)
        end
    end)
    iterate(snakeTrails, function(x, y, val)
        if val ~= " " then
            blitAt(x - scrollX, y - scrollY, "\127", "f", val)
        end
    end)
end

---@param player Player
local function drawPlayer(player)
    blitAt(player.pos.x - scrollX, player.pos.y - scrollY, player.char, "f", player.color)
end


---@param player Player
---@param key integer
---@return Vector?
local function handleKey(player, key)
    if (key == keys.up or key == keys.w) and not dirs.down:equals(player.lastAppliedVel) then
        return dirs.up
    elseif (key == keys.left or key == keys.a) and not dirs.right:equals(player.lastAppliedVel) then
        return dirs.left
    elseif (key == keys.right or key == keys.d) and not dirs.left:equals(player.lastAppliedVel) then
        return dirs.right
    elseif (key == keys.down or key == keys.s) and not dirs.up:equals(player.lastAppliedVel) then
        return dirs.down
    end
end

---Colors available for new players to join
local availableColors = {}
for i = 0, 14 do -- exclude black
    availableColors[#availableColors + 1] = colors.toBlit(2 ^ i)
end

local protocol = "imperialist_worm"

---- CLIENT specific

local host, playerColor
local function recieveFromHost(filter, timeout)
    while true do
        local source, mesg = rednet.receive(protocol, timeout)
        if not mesg then
            return
        elseif source == host and not filter or (mesg.type == filter) then
            return mesg
        end
    end
end
local extendedInfo = true

local function controlGame()
    while true do
        local _, dir = os.pullEvent("key")
        local player = players[playerColor]
        if player then
            local dirv = handleKey(player, dir)
            if dirv then
                rednet.send(host, { type = "dir", x = dirv.x, y = dirv.y }, protocol)
            end
        end
        if dir == keys.space then
            rednet.send(host, { type = "spawn" }, protocol)
        elseif dir == keys.tab then
            extendedInfo = not extendedInfo
        end
    end
end


local function renderGame()
    local draw = require "draw"
    while true do
        rootWin.setVisible(false)
        rootWin.setBackgroundColor(colors.black)
        rootWin.setTextColor(colors.white)
        rootWin.clear()
        draw.square(-scrollX, -scrollY, boardw + 2, boardh + 2, rootWin)
        drawField()
        for _, player in pairs(players) do
            drawPlayer(player)
        end
        if not players[playerColor] then
            draw.center_text(termh - 1, "You Died!", rootWin)
            draw.center_text(termh, "[Space]", rootWin)
        end
        draw.text(termw - 5, 1, "[Tab]", rootWin)
        for i, ownership in ipairs(landOwnershipTable) do
            if i > 3 and not extendedInfo then
                draw.text(termw - 2, i + 1, "...", rootWin)
                break
            end
            local text = ("%6s%%"):format(("%.2f"):format(ownership.percentage * 100))
            if extendedInfo then
                local name = players[ownership.color] and players[ownership.color].name or ""
                text = ("%s:%s"):format(name, text)
            end
            blitAt(
                termw - #text + 1,
                i + 1,
                text,
                (ownership.color):rep(#text),
                (" "):rep(#text)
            )
        end
        rootWin.setVisible(true)
        os.pullEvent("render")
        if players[playerColor] then
            -- alive
            local player = players[playerColor]
            local halfw = math.floor(termw / 2)
            scrollX = player.pos.x - halfw -- + player.lastAppliedVel.x
            local halfh = math.floor(termh / 2)
            scrollY = player.pos.y - halfh -- + player.lastAppliedVel.y

            scrollX = math.max(math.min(scrollX, boardw - termw + 1), -1)
            scrollY = math.max(math.min(scrollY, boardh - termh + 1), -1)
        end
    end
end

local function recieveTicks()
    while true do
        local mesg = recieveFromHost("tick", 3)
        if not mesg then
            term.clear()
            term.setCursorPos(1, 1)
            printError("Timed out")
            return
        end
        players = mesg.players
        snakeTrails = mesg.snakeTrails
        claimedLand = mesg.claimedLand
        landOwnershipTable = mesg.landOwnershipTable
        os.queueEvent("render")
    end
end

local function clientKeepAlive()
    while true do
        sleep(3)
        rednet.send(host, { type = "keepalive" }, protocol)
    end
end

local function waitForGameEnd()
    local msg = recieveFromHost("game_end") --[[@as table]]
    term.clear()
    term.setCursorPos(1, 1)
    print("The game is over!")
    print(msg.reason)
end

local isHost

--- Client join a hosted game
---@param name string
---@param hostname string?
local function joinGame(name, hostname)
    draw = require "draw"
    rednet.open("back")
    print("Looking up host...")
    host = rednet.lookup(protocol, hostname)
    if not host then
        printError("Could not find a host.")
        return
    end
    print("Attempting to join...")
    rednet.send(host, { type = "join", name = name }, protocol)
    local mesg = recieveFromHost("join_answer", 5)
    if not mesg then
        printError("Connection timed out.")
        return
    end
    if not mesg.success then
        printError("Game is full.")
        return
    end
    playerColor = mesg.color
    boardw = mesg.boardw
    boardh = mesg.boardh
    resetGame()
    print("Joined")
    rednet.send(host, { type = "spawn" }, protocol)
    local funcs = { controlGame, renderGame, clientKeepAlive, waitForGameEnd }
    if not isHost then
        funcs[#funcs + 1] = recieveTicks
    end
    parallel.waitForAny(table.unpack(funcs))
end

--- HOST specific

---@class Client
---@field color string
---@field id integer
---@field lastMessageTime integer
---@field name string

---@type table<integer,Client>
local connectedClients = {}
---@type table<string,Client>
local clientsByColor = {}

local function sendJoinAnswer(sender, color)
    rednet.send(sender, { type = "join_answer", success = true, color = color, boardh = boardh, boardw = boardw },
        protocol)
end

--- msg {type:"join",name:string}
--- response {type:"join_answer",success:boolean,color:string,boardw:integer,boardh:integer}
local function handleJoinMesg(sender, msg)
    if connectedClients[sender] then
        -- print(("Client %d successfully reconnected, color %s"):format(sender, connectedClients[sender].color))
        sendJoinAnswer(sender, connectedClients[sender].color)
        return
    end
    if #availableColors > 0 then
        local color = table.remove(availableColors, 1)
        connectedClients[sender] = {
            color = color,
            id = sender,
            lastMessageTime = os.epoch("utc"),
            name = msg.name:sub(1, 10)
        }
        clientsByColor[color] = connectedClients[sender]
        -- print(("Client %d successfully joined, assigned color %s"):format(sender, color))
        sendJoinAnswer(sender, color)
    else
        rednet.send(sender, { type = "join_answer", success = false }, protocol)
    end
end

--- msg {type:"spawn"}
local function handleSpawnMesg(sender, msg)
    if not connectedClients[sender] then return end
    local client = connectedClients[sender]
    if players[client.color] then
        killPlayer(players[client.color])
    end
    newPlayer(client.color, client.name)
    recomputeLand()
    -- print(("Client %d (%s) respawned."):format(sender, client.color))
end

--- msg {type:dir, x:integer, y:integer}
local function handleDirMesg(sender, msg)
    if not connectedClients[sender] then return end
    if type(msg.x) ~= "number" or type(msg.y) ~= "number" then
        return
    end
    local client = connectedClients[sender]
    local vel = vector.new(msg.x, msg.y, 0)
    if vel:length() ~= 1 then
        -- print(("Client %d sent bad movement packet."):format(sender))
        return -- invalid movement packet
    end
    if players[client.color] then
        local player = players[client.color]
        player.vel = vel
    end
end

local function handleMessages()
    while true do
        local sender, msg = rednet.receive(protocol)
        if msg.type == "join" then
            handleJoinMesg(sender, msg)
        elseif msg.type == "spawn" then
            handleSpawnMesg(sender, msg)
        elseif msg.type == "dir" then
            handleDirMesg(sender, msg)
        end
        if connectedClients[sender] then
            connectedClients[sender].lastMessageTime = os.epoch("utc")
        end
    end
end

local function serverWatchdog()
    while true do
        sleep(5)
        for id, client in pairs(connectedClients) do
            if client.lastMessageTime + 5000 < os.epoch("utc") then
                connectedClients[id] = nil
                if players[client.color] then
                    killPlayer(players[client.color])
                end
                availableColors[#availableColors + 1] = client.color
            end
        end
    end
end

local tickdelay = 0.1
local dominationPercentage = 0.75

local function broadcast(data)
    rednet.broadcast(data, protocol)
    -- if host then -- loopback broadcasts
    --     rednet.send(host, data, protocol)
    -- end
end

local function runGame()
    while true do
        for _, player in pairs(players) do
            if tickPlayer(player) then
                print(("Player %s died."):format(player.color))
            end
        end
        broadcast {
            type = "tick",
            players = players,
            claimedLand = claimedLand,
            snakeTrails = snakeTrails,
            landOwnershipTable =
                landOwnershipTable
        }
        os.queueEvent("render")
        local numberOneLandOwner = landOwnershipTable[1]
        if numberOneLandOwner and numberOneLandOwner.percentage > dominationPercentage then
            local reason = ("%s has claimed more than %d%% of the board!")
                :format(clientsByColor[numberOneLandOwner.color].name, math.floor(dominationPercentage * 100))
            broadcast {
                type = "game_end",
                reason = reason
            }
            term.clear()
            term.setCursorPos(1, 1)
            print("Game has ended because " .. reason)
            break
        end
        sleep(tickdelay)
    end
end

local function hostGame(hostname)
    isHost = true
    rednet.open("back")
    rednet.host(protocol, hostname)
    print("Hosting game.")
    os.queueEvent("iworm_server_started")
    parallel.waitForAny(handleMessages, runGame, serverWatchdog)
    rednet.unhost(protocol)
end

local function hostAndJoin(hostname, name)
    term.clear()
    term.setCursorPos(1, 1)
    parallel.waitForAny(function() hostGame(hostname) end, function()
        os.pullEvent("iworm_server_started")
        joinGame(name, hostname)
    end)
end

-- local args = { ... }
-- if args[1] == "host" then
--     parallel.waitForAny(function() hostGame("test") end, function()
--         os.pullEvent("iworm_server_started")
--         joinGame("asdf")
--     end)
-- else
--     joinGame("test")
-- end

local function joinMenu()
    local tui = require "touchui"
    local containers = require "touchui.containers"
    local input = require "touchui.input"

    local rootVbox = containers.vBox()
    rootVbox:setWindow(rootWin)

    local name = ""
    rootVbox:addWidget(input.inputWidget("Name", nil, function(value)
        name = value
    end))

    local hostname
    rootVbox:addWidget(input.inputWidget("Hostname?", nil, function(value)
        hostname = value
        if value == "" then
            hostname = nil
        end
    end))
    rootVbox:addWidget(tui.textWidget("Leave blank to accept first available game"))

    rootVbox:addWidget(input.buttonWidget("Join!", function(self)
        if #name > 0 then
            rootVbox.exit = true
        end
    end))

    tui.run(rootVbox, false, nil, true)

    term.clear()
    term.setCursorPos(1, 1)
    joinGame(name, hostname)
    sleep(3)
end

local function hostMenu()
    local tui = require "touchui"
    local containers = require "touchui.containers"
    local input = require "touchui.input"

    local rootVbox = containers.vBox()
    rootVbox:setWindow(rootWin)
    local scrollVbox = containers.scrollableVBox()
    rootVbox:addWidget(scrollVbox)

    local name = ""
    scrollVbox:addWidget(input.inputWidget("Name*", nil, function(value)
        name = value
    end), 2)

    local hostname = ""
    scrollVbox:addWidget(input.inputWidget("Hostname", nil, function(value)
        hostname = value
    end), 2)

    local widthInput = input.inputWidget("Width", function(s)
        return tonumber(s) and tonumber(s) > 0 --[[@as boolean]]
    end, function(value)
        boardw = tonumber(value) or boardw
    end)
    scrollVbox:addWidget(widthInput, 2)
    widthInput:setValue(tostring(boardw))

    local heightInput = input.inputWidget("Height", function(s)
        return tonumber(s) and tonumber(s) > 0 --[[@as boolean]]
    end, function(value)
        boardh = tonumber(value) or boardh
    end)
    scrollVbox:addWidget(heightInput, 2)
    heightInput:setValue(tostring(boardh))

    -- local dominationInput = input.inputWidget("Domination %", function(s)
    --     local n = tonumber(s)
    --     return n and n >= 0 and n <= 1 --[[@as boolean]]
    -- end, function(value)
    --     dominationPercentage = tonumber(value) or dominationPercentage
    -- end)
    local dominationLabel = tui.textWidget(" 50%", "c")
    local dominationInput = input.sliderWidget(0.5, 1, function(value)
        dominationPercentage = value
        dominationLabel:updateText(("%3d%%"):format(math.ceil(value * 100)))
    end, "Domination %")
    scrollVbox:addWidget(dominationInput, 2)
    scrollVbox:addWidget(dominationLabel, 1)
    -- dominationInput:setValue(tostring(dominationPercentage))

    local territoryKillToggle = input.toggleWidget("Territory Kill", function(state)
        territoryKill = state
    end)
    territoryKillToggle.state = true
    scrollVbox:addWidget(territoryKillToggle, 2)

    local tickInput = input.inputWidget("Tick Delay", function(s)
        return tonumber(s) and tonumber(s) >= 0 --[[@as boolean]]
    end, function(value)
        tickdelay = tonumber(value) or tickdelay
    end)
    scrollVbox:addWidget(tickInput, 2)
    tickInput:setValue(tostring(tickdelay))

    rootVbox:addWidget(input.buttonWidget("Host!", function(self)
        if #name > 0 and #hostname > 0 then
            rootVbox.exit = true
        end
    end), 3)

    tui.run(rootVbox, false, nil, true)

    term.clear()
    term.setCursorPos(1, 1)
    hostAndJoin(hostname, name)
    sleep(3)
end

local function rootMenu()
    local tui = require "touchui"
    local containers = require "touchui.containers"
    local input = require "touchui.input"

    local rootVbox = containers.vBox()
    rootVbox:setWindow(rootWin)

    rootVbox:addWidget(tui.textWidget("EMPIRES", "c", 1), 3)
    rootVbox:addWidget(tui.textWidget("OF", "c", 1), 3)
    rootVbox:addWidget(tui.textWidget("DIRT", "c", 1), 3)

    local option

    rootVbox:addWidget(input.buttonWidget("Join", function(self)
        option = "join"
        rootVbox.exit = true
    end))
    rootVbox:addWidget(input.buttonWidget("Host", function(self)
        option = "host"
        rootVbox.exit = true
    end))

    tui.run(rootVbox, false, nil, true)

    if option == "join" then
        joinMenu()
    else
        hostMenu()
    end
end

local args = { ... }

---@type table<string,{type:"value"|"flag",description:string}>
local allowedArgs = {
    help = { type = "flag", description = "Show this help" },
    width = { type = "value", description = "Board width" },
    height = { type = "value", description = "Board height" },
    dom = { type = "value", description = "Percentage of board owned to win [0,1]" },
    tick = { type = "value", description = "Tick delay in seconds" },
    notk = { type = "flag", description = "Don't kill players when they are captured" }
}

local function printHelp()
    print("EMPIRES OF DIRT")
    print("-- join name <hostname> [args]")
    print("Join a server with the given name. If hostname is not provided join the first found.")
    print("-- host hostname <name> [args]")
    print("If name is provided also join on this computer.")
    print("*** args")
    local argList = ""
    for k, v in pairs(allowedArgs) do
        local argLabel = k
        if v.type == "value" then
            argLabel = argLabel .. "=?"
        end
        argList = argList .. ("-%-10s|%s\n"):format(argLabel, v.description)
    end
    print(argList)
end

-- the arguments without - before them
local varArgs = {}

-- the recognized arguments passed into the program
local givenArgs = {}
for i = 1, #args do
    local v = args[i]
    if string.sub(v, 1, 1) == "-" then
        local full_arg_str = string.sub(v, 2)
        for arg_name, arg_info in pairs(allowedArgs) do
            if string.sub(full_arg_str, 1, arg_name:len()) == arg_name then
                -- this is an argument that is allowed
                if arg_info.type == "value" then
                    local arg_arg_str = string.sub(full_arg_str, arg_name:len() + 1)
                    assert(arg_arg_str:sub(1, 1) == "=" and arg_arg_str:len() > 1, "Expected =<value> on arg " ..
                        arg_name)
                    givenArgs[arg_name] = arg_arg_str:sub(2)
                elseif arg_info.type == "flag" then
                    givenArgs[arg_name] = true
                    break
                end
            end
        end
    else
        table.insert(varArgs, v)
    end
end

local function handleArgs()
    if varArgs[1] == "host" then
        if #varArgs < 2 then
            printHelp()
            return
        end
        boardh = tonumber(givenArgs.height) or boardh
        boardw = tonumber(givenArgs.width) or boardw
        dominationPercentage = tonumber(givenArgs.dom) or dominationPercentage
        tickdelay = tonumber(givenArgs.tick) or tickdelay
        territoryKill = not givenArgs.notk
        if varArgs[3] then
            hostAndJoin(args[2], args[3])
        else
            hostGame(args[2])
        end
    elseif varArgs[1] == "join" then
        if #varArgs < 2 then
            printHelp()
            return
        end
        joinGame(varArgs[2], varArgs[3])
    elseif varArgs[1] == "help" then
        printHelp()
    elseif givenArgs.help then
        printHelp()
    elseif remos then
        rootMenu()
    else
        term.clear()
        term.setCursorPos(1, 1)
        print("EMPIRES OF DIRT")
        print("Run with -help to see CLI usage.")
        term.write("(J)oin/(h)ost? ")
        local input = read()
        if input:lower() == "h" then
            term.write("Hostname? ")
            repeat
                input = read()
            until #input > 0
            local hostname = input
            term.write("Name? ")
            repeat
                input = read()
            until #input > 0
            local name = input
            hostAndJoin(hostname, name)
        else
            term.write("Name? ")
            repeat
                input = read()
            until #input > 0
            local name = input
            print("Hostname? ")
            term.write("Blank to search: ")
            ---@type string?
            local hostname = read()
            if hostname == "" then
                hostname = nil
            end
            joinGame(name, hostname)
        end
    end
end

local ok, err = pcall(handleArgs)
if not ok then
    term.setCursorPos(1, 1)
    error(err)
end
