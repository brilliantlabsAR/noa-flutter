require("graphics.min")
local data = require('data.min')
local rich_text = require('rich_text.min')
local camera = require('camera.min')
local code = require('code.min')

SCRIPT_VERSION = "v1.0.7"

local graphics = Graphics.new()

EXPOSURE_NUMBER = 10
local last_print_time = 0
local last_msg_time = 0
local listening = false
local sleep_started = false
local disconnected = false
local last_auto_exp = 0
-- Frame to phone flags
MESSAGE_GEN_FLAG = "\x10"
WILDCARD_GEN_FLAG = "\x12"
AUDIO_DATA_FLAG = "\x13"
TRANSFER_DONE_FLAG = "\x15"


-- Phone to Frame flags
CAPTURE_SETTINGS_MSG = 0x0d
MESSAGE_RESPONSE_FLAG = 0x20
HOLD_RESPONSE_FLAG = 0x23
DATA_MSG = 0x22
TAP_SUBS_FLAG = 0x10
CHECK_FW_VERSION_FLAG = 0x16
CHECK_SCRIPT_VERSION_FLAG = 0x17
LISTENING_FLAG = 0x11
STOP_LISTENING_FLAG = 0x12
AUDIO_DATA_NON_FINAL_MSG = 0x05
AUDIO_DATA_FINAL_MSG = 0x06
STOP_TAP_FLAG = 0x13

local function send_data(data)
    local try_until = frame.time.utc() + 2
    while frame.time.utc() < try_until do
        if pcall(frame.bluetooth.send, data) then
            return
        end
    end
end


local function handle_tap()
    pcall(frame.bluetooth.send, string.char(TAP_SUBS_FLAG))
end
data.parsers[MESSAGE_RESPONSE_FLAG] = rich_text.parse_rich_text
data.parsers[DATA_MSG] = code.parse_code
data.parsers[LISTENING_FLAG] = camera.parse_capture_settings

local function handle_messages()
    -- for data access from frame
    if data.app_data[DATA_MSG] ~= nil then
        local code_byte = data.app_data[DATA_MSG].value
        if code_byte == TAP_SUBS_FLAG then
            frame.imu.tap_callback(handle_tap)
        elseif code_byte == STOP_TAP_FLAG then
            frame.imu.tap_callback(nil)
        elseif code_byte == STOP_LISTENING_FLAG then
            frame.microphone.stop()
        elseif code_byte == CHECK_FW_VERSION_FLAG then
            send_data(string.char(CHECK_FW_VERSION_FLAG) .. frame.FIRMWARE_VERSION)
        elseif code_byte == CHECK_SCRIPT_VERSION_FLAG then
            send_data(string.char(CHECK_SCRIPT_VERSION_FLAG) .. SCRIPT_VERSION)
        elseif code_byte == HOLD_RESPONSE_FLAG then
            print("HOLD FOR RESPONSE")
            -- Do nothing, just keep awake
        end
        data.app_data[DATA_MSG] = nil
    end
    if (data.app_data[LISTENING_FLAG] ~= nil) then
        print("LISTENING")
        listening = true
        frame.microphone.start {}
        -- run auto exposure 10 times
        for i = 1, EXPOSURE_NUMBER do
            camera.run_auto_exposure()
        end
        camera.capture_and_send(data.app_data[LISTENING_FLAG])
        data.app_data[LISTENING_FLAG] = nil
    end
    -- To print response on Frame
    if (data.app_data[MESSAGE_RESPONSE_FLAG] ~= nil and data.app_data[MESSAGE_RESPONSE_FLAG].string ~= nil) then
        graphics:clear()
        graphics:append_text(data.app_data[MESSAGE_RESPONSE_FLAG].string, data.app_data[MESSAGE_RESPONSE_FLAG].emoji)
        data.app_data[MESSAGE_RESPONSE_FLAG] = nil
    end
end

local function transfer_audio_data()
    local mtu = frame.bluetooth.max_length()
    local audio_data_size = math.floor((mtu - 1) / 2) * 2
    local audio_data = nil

    for i=1,20 do
        audio_data = frame.microphone.read(audio_data_size)
        if audio_data == nil then
            print("STOPPED LISTENING")
            pcall(send_data, string.char(AUDIO_DATA_FINAL_MSG))
            listening = false
            break
        elseif audio_data ~= '' then
            pcall(send_data, string.char(AUDIO_DATA_NON_FINAL_MSG) .. audio_data)
        else
            break;
        end
    end
end

graphics:append_text("", "\u{F000D}")
collectgarbage("collect")

while true do
    local items_ready = data.process_raw_items()
    if items_ready > 0 then
        sleep_started = false
        disconnected = false
        rc, err = pcall(handle_messages)
        if not rc then
            print(err)
        end
        last_msg_time = frame.time.utc()
    end

    if frame.bluetooth.is_connected() == false and not disconnected then
        disconnected = true
        graphics:clear()
        graphics:append_text("", "\u{F000D}")
    end
    if frame.time.utc() - last_msg_time > 15 and not sleep_started and not listening then
        sleep_started = true
        graphics:clear()
        graphics:append_text("", "\u{F0008}")
    end
    if frame.time.utc() - last_print_time > 0.07 then
        graphics:print()
        last_print_time = frame.time.utc()
    end
    if frame.time.utc() - last_msg_time > 18 and sleep_started then
        frame.microphone.stop()
        frame.display.text(' ',1,1)
        frame.display.show()
        frame.sleep(0.05)
        frame.sleep()
    end
    if listening then
        transfer_audio_data()
    end
    frame.sleep(0.001)
    collectgarbage("collect")
end
