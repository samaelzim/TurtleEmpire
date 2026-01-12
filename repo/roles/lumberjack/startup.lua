peripheral.find("modem", rednet.open)

local packet = {
    protocol = "HIVE_V1",
    senderID = os.getComputerID(),
    targetID = -1,
    role     = "NULL",
    type     = "ASSIGNMENT_REQUEST",
    payload  = {}
}

print("Broadcasting request...")
rednet.broadcast(packet, "HIVE_DISCOVERY")