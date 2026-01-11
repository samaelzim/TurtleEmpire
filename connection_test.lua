-- find and open the modem
peripheral.find("modem", rednet.open())

-- construct the payload dynamically
local myPayLoad = {
    fuel = turtle.getFuelLevel(),
    state = "IDLE",
    x = 0, y = 0, z = 0
}

-- construct the full HiveNet v1 packet
local packet = {
    protocol = "HIVE_V1",
    senderID = os.getComputerID(),
    targetID = -1, -- -1 indicates Broadcast
    role = "MINER",
    type = "HEARTBEAT",
    payload = myPayLoad
}

--send the payload
print("Sending heartbeat...")
rednet.broadcast(packet, "HIVE_V1") -- we pass "HIVE_V1" as the protocol to filter noise