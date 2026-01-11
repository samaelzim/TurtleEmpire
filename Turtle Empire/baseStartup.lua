-- startup.lua for Base Computer
peripheral.find("modem", rednet.open)

print("Base Station Listening on ID: " ..os.getComputerID())

while true do
    local senderId, message, protocol = rednet.receive()
    print("Received from " ..senderId.. ":")
    print(textutils.serialize(message))
end
