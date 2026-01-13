-- ============================================================================
-- FILE: hive_net.lua
-- Role: Shared Network API (Bulletproof Edition)
-- Version: 1.2.1
-- ============================================================================
local net = {}
local HIVE_PROTOCOL = "HIVE_PROT_V1"
local net_id = os.getComputerID()

function net.init()
    local modem = peripheral.find("modem")
    if modem then
        rednet.open(peripheral.getName(modem))
        return true
    end
    return false
end

-- INTERNAL: Find ID by Role Name
local function resolve_id(target)
    if type(target) == "number" then return target end
    local lookup = rednet.lookup(HIVE_PROTOCOL, target)
    return lookup
end

-- BULLETPROOF SEND: Includes 3 retries and Handshake Wait
function net.send_safe(target, msg_type, payload)
    local targetID = resolve_id(target)
    if not targetID then return false end

    local packet = { 
        type = msg_type, 
        payload = payload, 
        sender = net_id,
        v = "1.2.1" 
    }
    
    for attempt = 1, 3 do
        rednet.send(targetID, packet, HIVE_PROTOCOL)
        
        -- Wait for ACK (Handshake)
        local sender, response = rednet.receive(HIVE_PROTOCOL, 2) 
        if sender == targetID and response and response.type == "ACK" then
            return true -- Delivery Confirmed
        end
        sleep(0.1 * attempt) -- Exponential backoff
    end
    return false -- Failed after 3 attempts
end

-- STANDARD SEND: For high-frequency data (No ACK needed)
function net.send(target, msg_type, payload)
    local targetID = resolve_id(target)
    if targetID then
        local packet = { 
            type = msg_type, 
            payload = payload, 
            sender = net_id,
            v = "1.2.1" 
        }
        rednet.send(targetID, packet, HIVE_PROTOCOL)
    end
end

-- RECEIVE: Filtered for convenience
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