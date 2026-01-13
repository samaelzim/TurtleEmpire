-- ============================================================================
-- FILE: hive_net.lua
-- Role: Shared Network API (OTA Enabled)
-- Version: 1.3.0
-- ============================================================================
local net = {}
local HIVE_PROTOCOL = "HIVE_PROT_V1"

function net.init()
    local modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
        return true
    end
    return false
end

function net.send_safe(target, msg_type, payload)
    local targetID = (type(target) == "number") and target or rednet.lookup(HIVE_PROTOCOL, target)
    if not targetID then return false end

    local packet = { type = msg_type, payload = payload, sender = os.getComputerID() }
    for attempt = 1, 3 do
        rednet.send(targetID, packet, HIVE_PROTOCOL)
        local sender, response = rednet.receive(HIVE_PROTOCOL, 2)
        if sender == targetID and response and response.type == "ACK" then
            return true
        end
        sleep(0.1 * attempt)
    end
    return false
end

function net.send(target, msg_type, payload)
    local targetID = (type(target) == "number") and target or rednet.lookup(HIVE_PROTOCOL, target)
    if targetID then
        rednet.send(targetID, { type = msg_type, payload = payload, sender = os.getComputerID() }, HIVE_PROTOCOL)
    end
end

function net.receive(filter_type, timeout)
    local sender, packet = rednet.receive(HIVE_PROTOCOL, timeout)
    if packet then
        if not filter_type or packet.type == filter_type then
            return packet, sender
        end
    end
    return nil, nil
end

return net