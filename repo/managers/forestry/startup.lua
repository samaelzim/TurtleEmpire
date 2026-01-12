peripheral.find("modem", rednet.open)
rednet.host("HIVE_DISCOVERY", "treeFarmManager "..os.getComputerID())
print("Manager Online. Waiting...")

while true do
    local sender_id, message, protocol = rednet.receive()
    
    -- Safety Check: Is it a table?
    if type(message) == "table" then
        -- Protocol Check: Is it HiveNet?
        if message.protocol == "HIVE_V1" then
            print("Received HIVE packet from ID: " .. sender_id)
            print( textutils.serialize(message) )
        end
    end
end