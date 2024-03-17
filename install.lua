local repositoryUrl = "https://raw.githubusercontent.com/MasonGulu/remos/main/"

local function fromURL(url)
    return { url = url }
end

local function fromRepository(url)
    return fromURL(repositoryUrl .. url)
end

local files = {
    ["browser.lua"] = fromRepository "browser.lua",
    icons = {
        ["default_icon_large.blit"] = fromRepository "icons/default_icon_large.blit",
        ["default_icon_small.blit"] = fromRepository "icons/default_icon_small.blit",
        ["worm_icon_large.blit"] = fromRepository "icons/worm_icon_large.blit",
        ["worm_icon_small.blit"] = fromRepository "icons/worm_icon_small.blit",
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
    ["startup.lua"] = fromRepository "startup.lua"
}
local alwaysOverwrite = false
local function downloadFile(path, url)
    print(string.format("Installing %s to %s", url, path))
    local response = assert(http.get(url, nil, true), "Failed to get " .. url)
    local writeFile = true
    if fs.exists(path) and not alwaysOverwrite then
        term.write("%s already exists, overwrite? Y/n/always? ")
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

local function downloadFiles(folder, files)
    for k, v in pairs(files) do
        local path = fs.combine(folder, k)
        if v.url then
            downloadFile(path, v.url)
        else
            fs.makeDir(path)
            downloadFiles(path, v)
        end
    end
end

downloadFiles("/", files)
