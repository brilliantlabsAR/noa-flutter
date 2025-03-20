Graphics = {}
Graphics.__index = Graphics

function Graphics.new()
    local self = setmetatable({}, Graphics)
    self:clear()
    return self
end

function Graphics:clear()
    -- Set by append_text function
    self.__text = ""
    self.__emoji = ""
    self.__rad = ""
    -- Used internally by print function
    self.__this_line = ""
    self.__last_line = ""
    self.__last_last_line = ""
    self.__starting_index = 1
    self.__current_index = 1
    self.__ending_index = 1
    self.__done_function = (function() end)()
end

function Graphics:append_text(data, emoji)
    self.__text = self.__text .. string.gsub(data, "\n+", " ")
    self.__emoji = emoji
end


function Graphics:on_complete(func)
    self.__done_function = func
end

function flash(t,c)
    frame.display.bitmap(241, 191, 160, 2, c, string.rep("\xFF", 20*t))
    frame.display.bitmap(311, 121, t, 2, c, string.rep("\xFF", 20*t))
end

function Graphics.__print_layout(last_last_line, last_line, this_line, emoji, rad)
    local TOP_MARGIN = 118
    local LINE_SPACING = 58
    local EMOJI_MAX_WIDTH = 91

    if rad == "A" then
        flash(10, 0)
    elseif rad == "C" then
        flash(20, 10)
    end
    frame.display.text(emoji, 640 - EMOJI_MAX_WIDTH, TOP_MARGIN, { color = 'YELLOW' })
    
    if last_last_line == '' and last_line == '' then
        frame.display.text(this_line, 1, TOP_MARGIN)
    elseif last_last_line == '' then
        frame.display.text(last_line, 1, TOP_MARGIN)
        frame.display.text(this_line, 1, TOP_MARGIN + LINE_SPACING)
    else
        frame.display.text(last_last_line, 1, TOP_MARGIN)
        frame.display.text(last_line, 1, TOP_MARGIN + LINE_SPACING)
        frame.display.text(this_line, 1, TOP_MARGIN + LINE_SPACING * 2)
    end

    frame.display.show()
end

function Graphics:print()
    if self.__text:sub(self.__starting_index, self.__starting_index) == ' ' then
        self.__starting_index = self.__starting_index + 1
    end

    if self.__current_index >= self.__ending_index then
        self.__starting_index = self.__ending_index
        self.__last_last_line = self.__last_line
        self.__last_line = self.__this_line
        self.__starting_index = self.__ending_index
    end

    for i = self.__starting_index + 22, self.__starting_index, -1 do
        if self.__text:sub(i, i) == ' ' or self.__text:sub(i, i) == '' then
            self.__ending_index = i
            break
        end
    end

    self.__this_line = self.__text:sub(self.__starting_index, self.__current_index)

    self.__print_layout(self.__last_last_line, self.__last_line, self.__this_line, self.__emoji, self.__rad)

    if self.__current_index >= #self.__text then
        pcall(self.__done_function)
        self.__done_function = (function() end)()
        return
    end

    self.__current_index = self.__current_index + 1
end
