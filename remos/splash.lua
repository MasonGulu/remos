local draw = require "draw"
local termW, termH = term.getSize()

draw.set_col(remos.theme.fg, remos.theme.bg, term)
term.clear()
local centerH = math.ceil(termH / 2)
draw.center_text(centerH - 3, "Welcome To", term)
draw.center_text(centerH - 2, "Remos", term, 1)
draw.center_text(centerH + 1, "By ShreksHellraiser", term)
draw.center_text(termH, "Enter to Skip", term)
local tid = os.startTimer(settings.get("remos.splash_screen_delay"))
while true do
    local e, id = os.pullEventRaw()
    if e == "terminate" then
        return -- end splash early
    elseif e == "key" and id == keys.enter then
        return
    elseif e == "timer" and tid == id then
        return
    end
end
