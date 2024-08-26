function send_data(data)
    while true do
        if (pcall(frame.bluetooth.send, data)) then
            break
        end
    end
end

data = string.rep('a', frame.bluetooth.max_length())

while true do
    for i = 1, 100 do send_data(data) end
    send_data('')
end
