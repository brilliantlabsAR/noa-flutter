require("graphics")
require("state")

SCRIPT_VERSION = "v1.0.5"

local graphics = Graphics.new()
local state = State.new()

local image_taken = false
local image_data_sent = false
local audio_data_sent = false
local last_autoexp_time = 0
local last_print_time = 0
local auto_exposure_number = 0
EXPOSURE_NUMBER = 10

-- Frame to phone flags
MESSAGE_GEN_FLAG = "\x10"
WILDCARD_GEN_FLAG = "\x12"
AUDIO_DATA_FLAG = "\x13"
IMAGE_DATA_FLAG = "\x14"
TRANSFER_DONE_FLAG = "\x15"
CHECK_FW_VERSION_FLAG = "\x16"
CHECK_SCRIPT_VERSION_FLAG = "\x17"

-- Phone to Frame flags
MESSAGE_RESPONSE_FLAG = "\x20"
IMAGE_RESPONSE_FLAG = "\x21"


local function send_data(data)
    local try_until = frame.time.utc() + 2
    while frame.time.utc() < try_until do
        if pcall(frame.bluetooth.send, data) then
            return
        end
    end
    state:switch("NO_CONNECTION")
end

local function bluetooth_callback(message)
    if string.sub(message, 1, 1) == MESSAGE_RESPONSE_FLAG then
        if state:is("ON_IT") or state:is("WILDCARD") then
            graphics:clear()
            state:switch("PRINT_REPLY")
        end
        if state:is("PRINT_REPLY") then
            graphics:append_text(string.sub(message, 2), "\u{F0003}")
        end
    elseif string.sub(message, 1, 1) == IMAGE_RESPONSE_FLAG then
        if state:is("ON_IT") then
            graphics:clear()
            state:switch("PRINT_IMAGE")
        end
    elseif string.sub(message, 1, 1) == CHECK_FW_VERSION_FLAG then
        send_data(CHECK_FW_VERSION_FLAG .. frame.FIRMWARE_VERSION)
    elseif string.sub(message, 1, 1) == CHECK_SCRIPT_VERSION_FLAG then
        send_data(CHECK_SCRIPT_VERSION_FLAG .. SCRIPT_VERSION)
    end
end

frame.bluetooth.receive_callback(bluetooth_callback)

while true do
    if state:is("START") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("look ahead", "\u{F0000}")
        end)
        local pos = frame.imu.direction()
        if pos['roll'] > -20 and pos['roll'] < 20 and pos['pitch'] > -60 and pos['pitch'] < 40 then
            state:switch("TAP_ME_IN")
        end
        state:switch_after(10, "SLEEP")
    elseif state:is('TAP_ME_IN') then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("tap me in", "\u{F0000}")
            -- graphics.__rad = "A"
        end)
        state:switch_after(10, "PRE_SLEEP")
        state:switch_on_tap("LISTEN")
        state:switch_on_double_tap("LISTEN")
    elseif state:is("PRE_SLEEP") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{F0008}")
        end)
        state:switch_after(3, "SLEEP")
        state:switch_on_tap("START")
        state:switch_on_double_tap("START")
    elseif state:is("SLEEP") then
        state:on_entry(function()
            frame.microphone.stop()
            frame.display.show()
            frame.sleep(0.05)
            frame.sleep()
        end)
    elseif state:is("LISTEN") then
        state:on_entry(function()
            image_taken = false
            graphics:clear()
            -- graphics.__rad = "A"
            graphics:append_text("tap to finish", "\u{F0010}")
            image_data_sent = false
            audio_data_sent = false
            send_data(MESSAGE_GEN_FLAG)
            frame.microphone.start {}
            auto_exposure_number = 0
        end)

        if auto_exposure_number > EXPOSURE_NUMBER and image_taken == false then
            frame.camera.capture { quality = "HIGH" , resolution = 720}
            image_taken = true
            -- graphics.__rad = "C"
        end

        if auto_exposure_number > (EXPOSURE_NUMBER + 3 ) and frame.camera.image_ready() and image_data_sent == false then
            while true do
                local image_data = frame.camera.read(frame.bluetooth.max_length() - 1)
                if (image_data == nil) then
                    break
                end
                send_data(IMAGE_DATA_FLAG .. image_data)
            end
            image_data_sent = true
        end

        local audio_data = frame.microphone.read(
            math.floor((frame.bluetooth.max_length() - 1) / 2) * 2
        )
        if audio_data ~= nil and audio_data ~= '' then
            send_data(AUDIO_DATA_FLAG .. audio_data)
        end

        if auto_exposure_number > (EXPOSURE_NUMBER+20) then
            state:switch_on_tap("ON_IT")
            state:switch_on_double_tap("TAP_ME_IN")
        end
        state:switch_after(EXPOSURE_NUMBER%10+8, "TAP_ME_IN")
    elseif state:is("ON_IT") then
        state:on_entry(function()
            frame.microphone.stop()
            graphics:clear()
            graphics:append_text("..................... ..................... .....................", "")
        end)
        if audio_data_sent == false then
            while true do
                local audio_data = frame.microphone.read(
                    math.floor((frame.bluetooth.max_length() - 1) / 2) * 2
                )
                if (audio_data == nil) then
                    break
                end
                if (audio_data ~= '') then
                    send_data(AUDIO_DATA_FLAG .. audio_data)
                end
            end
            audio_data_sent = true
            send_data(TRANSFER_DONE_FLAG)
        end
        state:switch_after(20, "CANCEL")
    elseif state:is("CANCEL") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{F0001}")
        end)
        state:switch_after(1, "TAP_ME_IN")
    elseif state:is("PRINT_REPLY") then
        graphics:on_complete(function()
            state:switch("HOLD_REPLY")
        end)
        state:switch_on_tap("LISTEN")
        state:switch_on_double_tap("LISTEN")
    elseif state:is("PRINT_IMAGE") then
        graphics:on_complete(function()
            state:switch("HOLD_REPLY")
        end)
        state:switch_on_tap("LISTEN")
        state:switch_on_double_tap("LISTEN")
    elseif state:is("HOLD_REPLY") then
        if math.random(1, 10) == 10 then
            -- state:switch_after(5, "WILDCARD") -- TODO disabled for now
            state:switch_after(5, "TAP_ME_IN")
        else
            state:switch_after(5, "TAP_ME_IN")
        end
        state:switch_on_tap("LISTEN")
        state:switch_on_double_tap("LISTEN")
    elseif state:is("WILDCARD") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{F000E}")
            send_data(WILDCARD_GEN_FLAG)
        end)
        state:switch_after(20, "CANCEL")
    elseif state:is("NO_CONNECTION") then
        state:on_entry(function()
            graphics:clear()
            graphics:append_text("", "\u{F000D}")
        end)
        if frame.bluetooth.is_connected() == true then
            state:switch("START")
        end
        state:switch_after(10, "PRE_SLEEP")
    else
        print("Error: Entered an undefined state: " .. state.__current_state)
    end

    if frame.time.utc() - last_autoexp_time > 0.1 then
        frame.camera.auto {}
        last_autoexp_time = frame.time.utc()
        auto_exposure_number = auto_exposure_number + 1
    end

    if frame.bluetooth.is_connected() == false then
        if (not state:is("PRE_SLEEP") and not state:is("SLEEP")) then
            state:switch("NO_CONNECTION")
        end
    end

    if frame.time.utc() - last_print_time > 0.07 then
        graphics:print()
        last_print_time = frame.time.utc()
    end

    collectgarbage("collect")
end
