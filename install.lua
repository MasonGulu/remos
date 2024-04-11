local repositoryUrl = "https://raw.githubusercontent.com/MasonGulu/remos/main/"

local function fromURL(url)
    return { url = url }
end

local function fromRepository(url)
    return fromURL(repositoryUrl .. url)
end

local files = {
    apps = {
        ["eod.lua"] = fromRepository "apps/eod.lua",
        ["browser.lua"] = fromRepository "apps/browser.lua",
        ["iconedit.lua"] = fromRepository "apps/iconedit.lua",
        ["themeedit.lua"] = fromRepository "apps/themeedit.lua"
    },
    config = {
        ["home_apps.table"] = fromRepository "config/home_apps.table",
    },
    icons = {
        ["browser.icon"] = fromRepository "icons/browser.icon",
        ["default.icon"] = fromRepository "icons/default.icon",
        ["eod.icon"] = fromRepository "icons/eod.icon",
        ["icon_edit.icon"] = fromRepository "icons/icon_edit.icon",
        ["missing.icon"] = fromRepository "icons/missing.icon",
        ["settings.icon"] = fromRepository "icons/settings.icon",
        ["shell.icon"] = fromRepository "icons/shell.icon",
        ["taskmon.icon"] = fromRepository "icons/taskmon.icon",
        ["theme_edit.icon"] = fromRepository "icons/theme_edit.icon",
        ["worm.icon"] = fromRepository "icons/worm.icon",
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
    remos = {
        ["home.lua"] = fromRepository "remos/home.lua",
        ["init.lua"] = fromRepository "remos/init.lua",
        ["kernel.lua"] = fromRepository "remos/kernel.lua",
        ["menu.lua"] = fromRepository "remos/menu.lua",
        ["notificationTray.lua"] = fromRepository "remos/notificationTray.lua",
        ["popup.lua"] = fromRepository "remos/popup.lua",
        ["settings.lua"] = fromRepository "remos/settings.lua",
        ["splash.lua"] = fromRepository "remos/splash.lua",
        ["taskmon.lua"] = fromRepository "remos/taskmon.lua",
    },
    themes = {
        palettes = {
            ["gnome.pal"] = fromRepository "themes/palettes/gnome.pal",
            ["solarized.pal"] = fromRepository "themes/palettes/solarized.pal",
        },
        ["advanced.theme"] = fromRepository "themes/advanced.theme",
        ["hotdog.theme"] = fromRepository "themes/hotdog.theme",
        ["solarized_dark.theme"] = fromRepository "themes/solarized_dark.theme",
        ["solarized_light.theme"] = fromRepository "themes/solarized_light.theme",
    },
    ["startup.lua"] = fromRepository "startup.lua"
}

local writeFile = true -- For debugging purposes

local w, h = term.getSize()
local margin = 2

term.setBackgroundColor(colors.white)
term.setTextColor(colors.lightGray)
term.clear()

term.setCursorPos(math.floor(w / 2 - #("Please wait") / 2), math.ceil(h / 2))
term.write("Please wait")

local strings = require("cc.strings")
local bigfont = load(
    assert(http.get("https://pastebin.com/raw/3LfWxRWh").readAll(), "Failed to download bigfont."),
    "bigfont",
    "bt",
    _ENV
)()

term.setTextColor(colors.black)
term.clear()

local function title()
    bigfont.writeOn(term, 1, "Remos", math.floor(w / 2 - #("Remos")) - 1, 2)
end

title()

local introduction = strings.wrap(
    "Welcome to Remos, an Android inspired shell for ComputerCraft.\n\nIn order to continue the installation, click on \"Continue\".\n\nHold CTRL+T to cancel.",
    w - (margin * 2)
)

for i, line in ipairs(introduction) do
    term.setCursorPos(margin, 5 + i)
    term.write(line)
end

local function button(label)
    term.setCursorPos(1, h - 2)
    term.write(string.char(0x97))
    term.write(string.char(0x83):rep(w - 2))
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.write(string.char(0x94))

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(1, h - 1)
    term.clearLine()
    term.write(string.char(0x95))
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(w, h - 1)
    term.write(string.char(0x95))

    term.setCursorPos(1, h)
    term.write(string.char(0x8a))
    term.write(string.char(0x8f):rep(w - 2))
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.write(string.char(0x85))

    term.setBackgroundColor(colors.white)
    term.setTextColor(colors.black)
    term.setCursorPos(math.ceil(w / 2 - #label / 2), h - 1)
    term.write(label)
end

button("Continue")

while true do
    local event, button, _, y = os.pullEventRaw()
    if event == "mouse_click" then
        if y >= h - 2 and button == 1 then
            break
        end
    elseif event == "terminate" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        return
    end
end

term.setBackgroundColor(colors.white)
term.setTextColor(colors.lightGray)

term.clear()

local info = strings.wrap(
    "Don't turn off the device, this might take a while",
    w - (margin * 2)
)

for i, line in ipairs(info) do
    term.setCursorPos(math.floor(w / 2 - #line / 2) + margin - 1, h - #info + i - 1)
    term.write(line)
end

term.setTextColor(colors.black)

title()

local function part(progress)
    return strings.wrap(
        ("Now installing\n%d%% complete"):format(progress),
        w - (margin * 2)
    )
end

local animation = "\133\131\138\151\143\148"
local inverse = "\151\143"

local cur, total = 0, 100
local successfull, reason = false, "Unknown exception"
parallel.waitForAny(
    function()
        local step = 1
        while true do
            local state = animation:sub(step, step)

            if inverse:find(state) then
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            else
                term.setBackgroundColor(colors.white)
                term.setTextColor(colors.black)
            end

            bigfont.writeOn(term, 1, state, math.floor(w / 2), math.floor(h / 2) - 2)

            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)

            step = step + 1
            if step > #animation then
                step = 1
            end

            local text = part(math.floor(100 / total * cur))
            for i, line in ipairs(text) do
                term.setCursorPos(math.floor(w / 2 - #line / 2) + margin - 1, math.floor(h / 2) + i + 1)
                term.write(line)
            end

            sleep(0.1)
        end
    end,
    function()
        local function deepCount(t)
            local i = 0
            for _, m in pairs(t) do
                if type(m) == "table" then
                    i = i + deepCount(m)
                else
                    i = i + 1
                end
            end
            return i
        end

        total = deepCount(files) * 1 -- One copy for downloading, the other for writing

        local function downloadFile(path, url)
            local response, err = http.get(url, nil, true)
            if not response then
                reason = ("Failed to get '%s'.\n%s"):format(url, err)
                return
            end

            local content = response.readAll()
            response.close()

            return content
        end

        local function count(t)
            local i = 0
            for _, _ in pairs(t) do
                i = i + 1
            end
            return i
        end

        local function applyFile(path, content)
            if writeFile then
                local f, err = fs.open(path, "wb")
                if not f then
                    reason = ("Cannot open file '%s'.\n%s"):format(path, err)
                    return
                end

                f.write(content)
                f.close()
            end
        end

        local function handleFiles(folder, files, handler)
            local total = count(files)
            local filen = 0
            for k, v in pairs(files) do
                filen = filen + 1
                local path = fs.combine(folder, k)

                if type(v) ~= "table" or v.url then
                    handler(v, path, files, k)
                    cur = cur + 1
                else
                    if writeFile then
                        fs.makeDir(path)
                    end
                    handleFiles(path, v, handler)
                end
            end
        end

        handleFiles("/", files, function(v, path, tab, k)
            tab[k] = downloadFile(path, v.url)
        end)

        handleFiles("/", files, function(v, path, tab, k)
            applyFile(path, v)
        end)

        successfull = true
    end
)

term.clear()

title()

local final = { "" }
if successfull then
    final = strings.wrap(
        "Installation complete! \2\n\nHold CTRL+T if wishing to make manual changes before applying the changes.",
        w - (margin * 2)
    )
else
    final = strings.wrap(
        ":(\nA fatal error has occurred. The installation has been cancelled.\n\nReason:\n\t" .. reason,
        w - (margin * 2)
    )
end

for i, line in ipairs(final) do
    term.setCursorPos(margin, 5 + i)
    term.write(line)
end

button("Restart")

while true do
    local event, button, _, y = os.pullEventRaw()
    if event == "mouse_click" then
        if y >= h - 2 and button == 1 then
            break
        end
    elseif event == "terminate" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        return
    end
end

os.reboot()
