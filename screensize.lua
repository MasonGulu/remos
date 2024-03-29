while true do
    term.clear()
    term.setCursorPos(1, 1)
    local w, h = term.getSize()
    print(w, h)
    if w == 26 and h == 18 then
        print("Pocket PC Sized")
    elseif w == 51 and h == 17 then
        print("Normal PC Sized")
    end
    os.pullEvent("term_resize")
end
