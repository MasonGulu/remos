local repositoryUrl = "https://raw.githubusercontent.com/MasonGulu/remos/main/"

local function fromURL(url)
    return { url = url }
end

local function fromRepository(url)
    return fromURL(repositoryUrl .. url)
end

local files = {
    ["draw.lua"] = fromRepository "libs/draw.lua",
    ["eod.lua"] = fromRepository "apps/eod.lua",
}
local function downloadFile(path, url)
    local response = assert(http.get(url, nil, true), "Failed to get " .. url)
    local writeFile = true
    if writeFile then
        local f = assert(fs.open(path, "wb"), "Cannot open file " .. path)
        f.write(response.readAll())
        f.close()
    end
    response.close()
end

local function printBar(percentage)
    term.clearLine()
    local w = term.getSize()
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

downloadFiles("/", files)
