Graphics = {}
Graphics.__index = Graphics

function Graphics.new()
    local self = setmetatable({}, Graphics)
    self:clear()
    return self
end

function Graphics:clear()
    self.__text = ""
    self.__emoji = ""
    self.__characters_printed = 0
    self.__image = ""
    self.__image_bytes_received = 0
    self.__image_printed = false
    frame.display.assign_color(1, 0x00, 0x00, 0x00)
    frame.display.assign_color(2, 0xFF, 0xFF, 0xFF)
end

function Graphics:append_text(data, emoji)
    self.__text = self.__text .. string.gsub(data, "\n+", " ")
    self.__emoji = emoji
end

function Graphics:append_image(data)
    local y = self.__image_bytes_received / 400 * 2
    frame.display.bitmap(120, y + 1, 400, 16, 0, data)
    self.__image_bytes_received = self.__image_bytes_received + #data
end

function Graphics:set_color(index, red, green, blue)
    frame.display.assign_color(index, red, green, blue)
end

function Graphics:on_complete(func)
    if (self.__characters_printed > 0 and self.__characters_printed == #self.__text) or
        self.__image_printed then
        pcall(func)
    end
end

function Graphics:print_text()
    -- Otherwise print text
    local TOP_MARGIN = 118
    local MAX_LINES = 3
    local LINE_SPACING = 58
    local EMOJI_MAX_WIDTH = 91
    local TEXT_MAX_WIDTH = 640 - EMOJI_MAX_WIDTH - 5
    local CHARACTER_WIDTH = 24
    local WORD_DELAY = 0.075

    -- Local variables
    local line_count = 1
    local lines = { "" }
    local accumulated_width = 0
    local trunkated_text = string.sub(self.__text, 1, self.__characters_printed)

    for word in string.gmatch(trunkated_text, "%S+") do
        for character in string.gmatch(word, "%S+") do
            if accumulated_width + (CHARACTER_WIDTH * #character) > TEXT_MAX_WIDTH then
                accumulated_width = 0
                line_count = line_count + 1
                if line_count > MAX_LINES then
                    for shifted_line = 0, MAX_LINES - 1 do
                        lines[line_count - MAX_LINES + shifted_line] = lines[line_count - MAX_LINES + shifted_line + 1]
                    end
                    line_count = line_count - 1
                end
                lines[line_count] = ""
            end
            accumulated_width = accumulated_width + (CHARACTER_WIDTH * #character) + 24
            lines[line_count] = lines[line_count] .. " " .. word
        end
    end

    -- Print to the display
    for i, line in pairs(lines) do
        local y = 1 + ((i - 1) * LINE_SPACING) + TOP_MARGIN
        frame.display.text(line, 1, y)
    end

    frame.display.text(self.__emoji, 640 - EMOJI_MAX_WIDTH, TOP_MARGIN)

    frame.display.show()

    -- Delay for appropriate time
    if string.sub(self.__text, self.__characters_printed, self.__characters_printed) == " " then
        frame.sleep(WORD_DELAY)
    end

    -- Increment for the next print
    if self.__characters_printed < #self.__text then
        self.__characters_printed = self.__characters_printed + 1
    end
end

function Graphics:print_image()
    if self.__image_bytes_received == 80000 and self.__image_printed == false then
        frame.display.show()
        frame.sleep(0.02)
        self.__image_printed = true
    end
end
