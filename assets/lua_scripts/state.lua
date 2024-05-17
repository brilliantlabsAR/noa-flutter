State = {}
State.__index = State

local TAP_DEBOUNCE_TIME = 0.05
local DOUBLE_TAP_CUTOFF_TIME = 0.25

function State.new()
    local self = setmetatable({}, State)
    self.__previous_state = "START"
    self.__current_state = "START"
    self.__next_state = "START"
    self.__entry_time = frame.time.utc()
    self.__entered = true
    self.__tap_time = 0
    self.__last_tap_time = 0
    self.__tap_handled = true
    frame.imu.tap_callback(function()
        if frame.time.utc() > self.__tap_time + TAP_DEBOUNCE_TIME then
            self.__last_tap_time = self.__tap_time
            self.__tap_time = frame.time.utc()
            self.__tap_handled = false
        end
    end)
    print("State: " .. tostring(self.__current_state))
    return self
end

function State:is(state)
    if self.__current_state == state then
        return true
    end
    return false
end

function State:switch_after(wait_time, __next_state)
    if __next_state ~= self.__next_state then
        self.__next_state = __next_state
    end
    if self.__current_state ~= self.__next_state then
        if frame.time.utc() - self.__entry_time >= wait_time then
            self.__previous_state = self.__current_state
            self.__current_state = self.__next_state
            self.__entry_time = frame.time.utc()
            self.__entered = true
            self.__tap_handled = true
            print("State: " .. tostring(self.__current_state))
        end
    end
end

function State:switch(state)
    self:switch_after(0, state)
end

function State:switch_on_tap(state)
    if self.__tap_handled then
        return
    end
    if frame.time.utc() - self.__tap_time > DOUBLE_TAP_CUTOFF_TIME and
        self.__tap_time - self.__last_tap_time > DOUBLE_TAP_CUTOFF_TIME then
        print("Tapped")
        self:switch(state)
    end
end

function State:switch_on_double_tap(state)
    if self.__tap_handled then
        return
    end
    if self.__tap_time - self.__last_tap_time <= DOUBLE_TAP_CUTOFF_TIME then
        print("Double tapped")
        self:switch(state)
    end
end

function State:has_been()
    return frame.time.utc() - self.__entry_time
end

function State:on_entry(func)
    if self.__entered == true then
        self.__entered = false
        pcall(func)
    end
end
