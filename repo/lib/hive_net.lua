-- ============================================================================
-- LIB: HIVE_NET (Network Communication Wrapper)
-- Location: repo/lib/hive_net.lua
-- Usage: local net = require("hive_net")
-- ============================================================================

local net = {}
local LIB_VERSION = "1.0.0" -- << Version Control

-- CONFIGURATION
local PROTOCOL_MAIN = "HIVE_V1"        
local HOST_PROTOCOL = "HIVE_DISCOVERY" 

-- EXPOSE VERSION
net.VERSION = LIB_VERSION

-- 1. INITIALIZATION
-- Finds a modem, opens it, and returns true if successful.
function net.init()
    local modem = peripheral.find("modem")
    if not modem then
        return false, "No Modem Found"
    end
    
    rednet.open(peripheral.getName(modem))
    return true
end

-- 2. SEND MESSAGE
-- Wraps data in a standard HIVE packet
function net.send(target_id, msg_type, payload)
    local packet = {
        protocol = PROTOCOL_MAIN,
        type     = msg_type,
        sender   = os.getComputerID(),
        lib_ver  = LIB_VERSION,     -- Attach version to packet for debugging
        payload  = payload or {}
    }
    
    if type(target_id) == "string" then
        -- BROADCAST (e.g. target_id = "MINERS")
        rednet.broadcast(packet, target_id)
    else
        -- DIRECT WHISPER (e.g. target_id = 12)
        rednet.send(target_id, packet, PROTOCOL_MAIN)
    end
end

-- 3. RECEIVE MESSAGE
-- Waits for a specific message type from a specific sender
function net.receive(filter_type, filter_sender, timeout)
    local timer = nil
    if timeout then
        timer = os.startTimer(timeout)
    end
    
    while true do
        local event, id, msg, proto = os.pullEvent()
        
        -- CASE A: TIMEOUT
        if event == "timer" and id == timer then
            return nil, "TIMEOUT"
        end
        
        -- CASE B: REDNET MESSAGE
        if event == "rednet_message" then
            if proto == PROTOCOL_MAIN or proto == HOST_PROTOCOL then
                if type(msg) == "table" then
                    
                    local type_match = (not filter_type) or (msg.type == filter_type)
                    local sender_match = (not filter_sender) or (id == filter_sender)
                    
                    if type_match and sender_match then
                        return msg, id
                    end
                end
            end
        end
    end
end

return net