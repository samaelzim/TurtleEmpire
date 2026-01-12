-- ============================================================================
-- MANAGER: BASE STATION
-- Location: repo/managers/base/base_station.lua
-- ============================================================================
package.path = package.path .. ";repo/lib/?.lua"
local net = require("hive_net")
local VERSION = "1.0.0"

-- MANIFEST: The files we send to new turtles
-- Format: { "Local_Path_On_Base", "Save_Name_On_Turtle" }
local MANIFEST = {
    common = {
        { "repo/lib/hive_net.lua", "hive_net.lua" }
    },
    roles = {
        -- We will build the actual miner code next, for now this points to the file
        MINER = { { "repo/roles/miner/startup.lua", "startup.lua" } }
    }
}

-- 1. INITIALIZATION
term.clear()
print("HIVE BASE STATION (v" .. VERSION .. ")")
print("-----------------------------------")

-- Initialize the Modem using our Library
if not net.init() then 
    error("Modem check failed! Is it equipped?") 
end

-- 2. FILE SENDING HELPER
local function send_file(target_id, file_path, save_name)
    print(">> Sending: " .. save_name)
    
    -- Open the file from the Base's hard drive
    local f = fs.open(file_path, "r")
    if not f then 
        print("!! ERROR: File not found on Base: " .. file_path)
        return 
    end
    local content = f.readAll()
    f.close()
    
    -- Send the file content using HIVE_NET
    net.send(target_id, "FILE_TRANSFER", {
        name = save_name,
        content = content
    })
    sleep(0.5) -- Small delay to prevent network flooding
end

-- 3. MAIN SERVER LOOP
print("Waiting for Assignment Requests...")

while true do
    -- Listen specifically for the "DISCOVERY_PING" message type
    -- net.receive(Type, Sender, Timeout) -> Timeout is nil so we wait forever
    local msg, sender_id = net.receive("DISCOVERY_PING", nil, nil)
    
    if msg then
        term.clear()
        term.setCursorPos(1,1)
        print("CONNECTION REQUEST: ID [" .. sender_id .. "]")
        print("Installer Version: " .. (msg.payload.version or "Unknown"))
        
        print("\nSelect Role for ID " .. sender_id .. ":")
        print(" [1] MINER")
        print(" [X] Cancel")
        
        local input = read()
        
        if input == "1" then
            print(">> Provisioning MINER...")
            
            -- 1. Send Common Files (Network Lib)
            for _, file in pairs(MANIFEST.common) do
                send_file(sender_id, file[1], file[2])
            end
            
            -- 2. Send Role Files (Miner Startup)
            for _, file in pairs(MANIFEST.roles.MINER) do
                send_file(sender_id, file[1], file[2])
            end
            
            -- 3. Send Reboot Command
            net.send(sender_id, "COMMAND", { cmd = "REBOOT" })
            print(">> Provisioning Complete. Waiting for next...")
            
        else
            print("Cancelled.")
        end
        
        sleep(2)
        term.clear()
        print("HIVE BASE STATION (v" .. VERSION .. ")")
        print("Waiting for Assignment Requests...")
    end
end