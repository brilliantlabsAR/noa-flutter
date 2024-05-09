require("graphics")
require("state")

local graphics = Graphics.new()
local state = State.new()

local image_taken = false
local image_data_sent = false
local audio_data_sent = false
local last_autoexp_time = 0

MESSAGE_START_FLAG = "\x10"
MESSAGE_TEXT_FLAG = "\x11"
MESSAGE_AUDIO_FLAG = "\x12"
MESSAGE_IMAGE_FLAG = "\x13"
MESSAGE_END_FLAG = "\x16"
MESSAGE_WILDCARD_FLAG = "\x17"

local function bluetooth_callback(message)
    if string.sub(message, 1, 1) == MESSAGE_TEXT_FLAG then
        if state:is("ON_IT") or state:is("WILDCARD") then
            graphics:clear()
            state:switch("PRINT_REPLY")
        end
        if state:is("PRINT_REPLY") then
            graphics:append_text(string.sub(message, 2), "\u{1F60E}")
        end
    end
end

local function send_data(data)
    local try_until = frame.time.utc() + 2
    while frame.time.utc() < try_until do
        if pcall(frame.bluetooth.send, data) then
            return
        end
    end
    state:switch("NO_CONNECTION")
end

frame.bluetooth.receive_callback(bluetooth_callback)

while true do
    if state:is("START") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F618}")
        end)
        state:switch_after(10, "WILDCARD")
        state:switch_on_tap("LISTEN")
    elseif state:is("WILDCARD") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F603}")
            send_data(MESSAGE_WILDCARD_FLAG)
        end)
        state:switch_after(10, "PRE_SLEEP")
    elseif state:is("READY_A") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{1F600}")
        end)
        state:switch_after(3, "READY_B")
        state:switch_on_tap("LISTEN")
    elseif state:is("READY_B") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F60F}")
        end)
        state:switch_after(3, "READY_C")
        state:switch_on_tap("LISTEN")
    elseif state:is("READY_C") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F600}")
        end)
        state:switch_after(3, "PRE_SLEEP")
        state:switch_on_tap("LISTEN")
    elseif state:is("PRE_SLEEP") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F634}")
        end)
        state:switch_after(3, "SLEEP")
        state:switch_on_tap("READY_A")
    elseif state:is("SLEEP") then
        state:on_entry(function()
            frame.sleep()
        end)
    elseif state:is("LISTEN") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{1F3A7}")
            frame.microphone.record {}
            send_data(MESSAGE_START_FLAG)
            image_taken = false
            image_data_sent = false
            audio_data_sent = false
        end)

        if state:has_been() > 0.2 and image_taken == false then
            frame.camera.capture()
            image_taken = true
        end

        if state:has_been() > 1.4 and image_data_sent == false then
            while true do
                local image_data = frame.camera.read(frame.bluetooth.max_length() - 1)
                if (image_data == nil) then
                    break
                end
                send_data(MESSAGE_IMAGE_FLAG .. image_data)
            end
            image_data_sent = true
        end

        local audio_data = frame.microphone.read(
            math.floor((frame.bluetooth.max_length() - 1) / 4) * 4
        )
        if audio_data ~= nil then
            send_data(MESSAGE_AUDIO_FLAG .. audio_data)
        end

        if state:has_been() > 2 then
            state:switch_on_tap("ON_IT")
        end
        state:switch_after(10, "ON_IT")
    elseif state:is("ON_IT") then
        state:on_entry(function()
            frame.microphone.stop()
            graphics:append_text("", "\u{1F603}")
        end)
        if state:has_been() > 1.4 and audio_data_sent == false then
            while true do
                local audio_data = frame.microphone.read(
                    math.floor((frame.bluetooth.max_length() - 1) / 4) * 4
                )
                if (audio_data == nil) then
                    break
                end
                send_data(MESSAGE_AUDIO_FLAG .. audio_data)
            end
            audio_data_sent = true
            send_data(MESSAGE_END_FLAG)
        end
        state:switch_on_tap("CANCEL")
    elseif state:is("CANCEL") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F910}")
        end)
        state:switch_after(1, "LISTEN")
    elseif state:is("PRINT_REPLY") then
        graphics:on_complete(function()
            state:switch("HOLD_REPLY")
        end)
        state:switch_on_tap("LISTEN")
    elseif state:is("HOLD_REPLY") then
        state:switch_on_tap("LISTEN")
        state:switch_after(3, "READY_A")
    elseif state:is("NO_CONNECTION") then
        state:on_entry(function()
            graphics:append_text("", "\u{1F4F5}")
        end)
        if frame.bluetooth.is_connected() == true then
            state:switch("START")
        end
        state:switch_after(10, "PRE_SLEEP")
    end

    graphics:print_text()

    if frame.time.utc() - last_autoexp_time > 0.1 then
        frame.camera.auto { metering = 'CENTER_WEIGHTED', exposure = -0.5, exposure_limit = 5500 }
        last_autoexp_time = frame.time.utc()
    end

    if frame.bluetooth.is_connected() == false then
        state:switch("NO_CONNECTION")
    end

    collectgarbage("collect")
end
