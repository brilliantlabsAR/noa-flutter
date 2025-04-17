-- Module to parse text strings sent from phoneside app as TxRichText messages
local _M = {}

local colors = {'VOID', 'WHITE', 'GREY', 'RED', 'PINK', 'DARKBROWN','BROWN', 'ORANGE', 'YELLOW', 'DARKGREEN', 'GREEN', 'LIGHTGREEN', 'NIGHTBLUE', 'SEABLUE', 'SKYBLUE', 'CLOUDBLUE'}

-- Parse the TxRichText message raw data, which is a string and an emoji with position and color information
function _M.parse_rich_text(data)
	local rich_text = {}

	rich_text.x = string.byte(data, 1) << 8 | string.byte(data, 2)
	rich_text.y = string.byte(data, 3) << 8 | string.byte(data, 4)
	rich_text.palette_offset = string.byte(data, 5)
	rich_text.color = colors[rich_text.palette_offset % 16 + 1]
	rich_text.spacing = string.byte(data, 6)
    local str_l = string.byte(data, 7)
	rich_text.string = string.sub(data, 8, 8 + str_l)
    rich_text.emoji = string.sub(data, 8 + str_l)
	return rich_text
end

return _M