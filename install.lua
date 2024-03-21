local repositoryUrl = "https://raw.githubusercontent.com/MasonGulu/remos/main/"

local function fromURL(url)
    return { url = url }
end

local function fromRepository(url)
    return fromURL(repositoryUrl .. url)
end

local files = {
    icons = {
        ["default_icon_large.blit"] = fromRepository "icons/default_icon_large.blit",
        ["default_icon_small.blit"] = fromRepository "icons/default_icon_small.blit",
        ["worm_icon_large.blit"] = fromRepository "icons/worm_icon_large.blit",
        ["worm_icon_small.blit"] = fromRepository "icons/worm_icon_small.blit",
        ["eod_icon_large.blit"] = fromRepository "icons/eod_icon_large.blit",
        ["eod_icon_small.blit"] = fromRepository "icons/eod_icon_small.blit",
        ["iconedit_icon_large.blit"] = fromRepository "icons/iconedit_icon_large.blit",
        ["iconedit_icon_small.blit"] = fromRepository "icons/iconedit_icon_small.blit",
        ["unknown_icon_large.blit"] = fromRepository "icons/unknown_icon_large.blit",
        ["unknown_icon_small.blit"] = fromRepository "icons/unknown_icon_small.blit",
    },
    remos = {
        ["home.lua"] = fromRepository "remos/home.lua",
        ["init.lua"] = fromRepository "remos/init.lua",
        ["kernel.lua"] = fromRepository "remos/kernel.lua",
        ["menu.lua"] = fromRepository "remos/menu.lua",
        ["popup.lua"] = fromRepository "remos/popup.lua",
        ["taskmon.lua"] = fromRepository "remos/taskmon.lua",
        ["settings.lua"] = fromRepository "remos/settings.lua"
    },
    libs = {
        touchui = {
            ["containers.lua"] = fromRepository "libs/touchui/containers.lua",
            ["init.lua"] = fromRepository "libs/touchui/init.lua",
            ["input.lua"] = fromRepository "libs/touchui/input.lua",
            ["lists.lua"] = fromRepository "libs/touchui/lists.lua",
            ["popups.lua"] = fromRepository "libs/touchui/popups.lua",
        },
        ["fe.lua"] = fromRepository "libs/fe.lua",
        ["draw.lua"] = fromRepository "libs/draw.lua",
        ["bigfont.lua"] = fromURL "https://pastebin.com/raw/3LfWxRWh"
    },
    config = {
        ["home_apps.table"] = fromRepository "config/home_apps.table",
    },
    apps = {
        ["eod.lua"] = fromRepository "apps/eod.lua",
        ["browser.lua"] = fromRepository "apps/browser.lua",
        ["iconedit.lua"] = fromRepository "apps/iconedit.lua",
    },
    ["startup.lua"] = fromRepository "startup.lua"
}
local alwaysOverwrite = false
local function downloadFile(path, url)
    local response = assert(http.get(url, nil, true), "Failed to get " .. url)
    local writeFile = true
    if fs.exists(path) and not alwaysOverwrite then
        term.write(("%s already exists, overwrite? Y/n/always? "):format(path))
        local i = io.read():sub(1, 1)
        alwaysOverwrite = i == "a"
        writeFile = alwaysOverwrite or i ~= "n"
    end
    if writeFile then
        local f = assert(fs.open(path, "wb"), "Cannot open file " .. path)
        f.write(response.readAll())
        f.close()
    end
    response.close()
end

local function printBar(percentage)
    term.clearLine()
    local _, w = term.getSize()
    local filledw = math.ceil(percentage * (w - 2))
    local bar = "[" .. ("*"):rep(filledw) .. (" "):rep(w - filledw - 2) .. "]"
    print(bar)
end

local function count(t)
    local i = 0
    for _, _ in pairs(t) do
        i = i + 1
    end
    return i
end

local function printProgress(y, path, percent)
    term.setCursorPos(1, y)
    printBar(percent)
    term.clearLine()
    print(path)
end

local function downloadFiles(folder, files)
    local total = count(files)
    local filen = 0
    local _, y = term.getCursorPos()
    for k, v in pairs(files) do
        filen = filen + 1
        local path = fs.combine(folder, k)
        printProgress(y, path, filen / total)
        if v.url then
            downloadFile(path, v.url)
        else
            fs.makeDir(path)
            downloadFiles(path, v)
        end
    end
    term.setCursorPos(1, y)
    term.clearLine()
    term.setCursorPos(1, y + 1)
    term.clearLine()
end

term.clear()
term.setCursorPos(1, 1)
print("Installing Remos...")

downloadFiles("/", files)
