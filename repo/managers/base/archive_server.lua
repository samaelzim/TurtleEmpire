-- ============================================================================
-- FILE: archive_server.lua
-- Role: Master File Server for Base Trio and Fleet
-- Version: 1.2.1
-- ============================================================================
package.path = package.path .. ";repo/lib/?.lua"
local net = require("hive_net")
local VERSION = "1.2.1"

-- 1. THE MASTER MANIFEST
-- Defines which files are sent to which role.
local MANIFEST = {
    common = {
        { "repo/lib/hive_net.lua", "hive_net.lua" },
    },
    system = {
        HIVE_BRAIN   = { { "repo/managers/base/brain_core.lua", "startup.lua" } },
        HIVE_CONSOLE = { { "repo/managers/base/console_ui.lua", "startup.lua" } },
    },
    fleet = {        
        MINER_TURTLE  = { 
            { "repo/lib/turtle_move.lua", "turtle_move.lua" },
            { "repo/roles/miner/startup.lua", "startup.lua" } 
        },
        MINER_MANAGER = { { "repo/managers/mining/startup.lua", "startup.lua" } }
    }
}

-- 2. FILE TRANSMISSION HELPER
-- Reads from the Archive's local 'repo' and sends to the target
local function send_file(target_id, file_path, save_name)
    print(">> Preparing: " .. save_name)
    
    if not fs.exists(file_path) then
        print("!! ERROR: Source file missing: " .. file_path)
        return false
    end

    local f = fs.open(file_path, "r")
    local content = f.readAll()
    f.close()
    
    -- Using net.send_safe ensures the target computer actually received the file
    local success = net.send_safe(target_id, "FILE_TRANSFER", {
        name = save_name,
        content = content
    })

    if success then
        print(">> Sent: " .. save_name)
    else
        print("!! Failed to send: " .. save_name)
    end
    
    return success
end

-- 3. ROLE SELECTION UI
local function get_role_files(choice)
    local selected = {}
    -- Always include common libraries
    for _, f in ipairs(MANIFEST.common) do table.insert(selected, f) end

    if choice == "B" then
        for _, f in ipairs(MANIFEST.system.HIVE_BRAIN) do table.insert(selected, f) end
    elseif choice == "C" then
        for _, f in ipairs(MANIFEST.system.HIVE_CONSOLE) do table.insert(selected, f) end
    elseif choice == "1" then
        for _, f in ipairs(MANIFEST.fleet.MINER_TURTLE) do table.insert(selected, f) end
    elseif choice == "2" then
        for _, f in ipairs(MANIFEST.fleet.MINER_MANAGER) do table.insert(selected, f) end
    else
        return nil
    end
    return selected
end

-- 4. INITIALIZATION
term.clear()
term.setCursorPos(1,1)
print("HIVE ARCHIVE SERVER v" .. VERSION)
print("-----------------------------------")

if not net.init() then 
    error("Modem check failed! Is it equipped?") 
end

-- Register as the Archive so the Provision Disk can find it
rednet.host("HIVE_PROT_V1", "HIVE_ARCHIVE")
print("Archive Online. Waiting for pings...")

-- 5. MAIN SERVER LOOP
while true do
    -- Listen for DISCOVERY_PING from a provision disk/new device
    local msg, sender_id = net.receive("DISCOVERY_PING")
    
    if msg then
        -- Bulletproof ACK for the Ping
        net.send(sender_id, "ACK", {received_type = "DISCOVERY_PING"})

        term.clear()
        print("PROVISION REQUEST: ID [" .. sender_id .. "]")
        print("-----------------------------------")
        print("SYSTEM ROLES:")
        print(" [B] HIVE_BRAIN")
        print(" [C] HIVE_CONSOLE")
        print("\nFLEET ROLES:")
        print(" [1] MINER_TURTLE")
        print(" [2] MINER_MANAGER")
        print("\n [X] Ignore/Cancel")
        
        write("\nAssign Role: ")
        local input = read():upper()
        
        local filesToPush = get_role_files(input)
        
        if filesToPush then
            print("\n>> Deploying to ID " .. sender_id .. "...")
            local all_ok = true
            
            for _, fileData in ipairs(filesToPush) do
                if not send_file(sender_id, fileData[1], fileData[2]) then
                    all_ok = false
                    break
                end
            end
            
            if all_ok then
                print(">> All files verified. Sending REBOOT...")
                net.send_safe(sender_id, "COMMAND", { cmd = "REBOOT" })
            else
                print("!! Deployment failed. Check file paths.")
            end
        else
            print("Action cancelled.")
        end
        
        print("\nPress any key to return to listener...")
        os.pullEvent("key")
        term.clear()
        print("HIVE ARCHIVE SERVER v" .. VERSION)
        print("Waiting for pings...")
    end
end