-- ============================================================================
-- HIVE BASE STATION (SERVER)
-- ============================================================================

-- THE MANIFEST: The Single Source of Truth for all versions
local MANIFEST = {
    system_name = "HIVE_BASE",
    base_version = "1.0.0",          -- The version of THIS script
    
    -- The Installer Version we expect Turtles to use
    installer_target = "1.0.0",      

    -- Role Definitions and their specific versions
    roles = {
        MINER = {
            version = "1.0.0",
            files = {
                { "repo/miner/miner_startup.lua", "startup.lua" },
                { "repo/common/hive_net.lua",    "hive_net.lua" }
            }
        },
        LUMBERJACK = {
            version = "1.0.0",
            files = {
                { "repo/lumber/lumber_startup.lua", "startup.lua" },
                { "repo/lumber/chop.lua",           "chop.lua" }
            }
        },
        FARMER = {
            version = "1.0.0",
            files = {
                { "repo/farmer/farm_startup.lua",   "startup.lua" },
                { "repo/common/hive_net.lua",       "hive_net.lua" }
            }
        }
    }
}

-- 2. SETUP NETWORK
peripheral.find("modem", rednet.open)
rednet.host("HIVE_DISCOVERY", "base_station_1")

-- 3. HELPER: SEND FILES WITH VERSION INJECTION
local function provision_device(target_id, role_key)
    local role_data = MANIFEST.roles[role_key]
    if not role_data then return false end

    print(" >> Deploying " .. role_key .. " (v" .. role_data.version .. ") to #" .. target_id)

    -- 1. Send all files
    for _, file_def in ipairs(role_data.files) do
        local source = file_def[1]
        local dest   = file_def[2]
        
        if fs.exists(source) then
            local f = fs.open(source, "r")
            local content = f.readAll()
            f.close()

            -- INJECT VERSION if it is the startup file
            if dest == "startup.lua" then
                local header = "local VERSION = '" .. role_data.version .. "'\n"
                content = header .. content
            end

            rednet.send(target_id, {
                type = "FILE_PUSH",
                filename = dest,
                content = content
            }, "HIVE_V1")
            sleep(0.2) -- Small delay to prevent network spam
        else
            print("ERR: Missing file " .. source)
        end
    end

    -- 2. Send Manager ID (Placeholder for now)
    -- We can expand this later to pick a specific manager
    rednet.send(target_id, {
        type = "FILE_PUSH",
        filename = ".manager",
        content = "0" -- Default ID
    }, "HIVE_V1")

    -- 3. Send Reboot Command
    sleep(1)
    rednet.send(target_id, { type = "REBOOT" }, "HIVE_V1")
    print(" >> Provisioning Complete.")
end

-- 4. MAIN UI LOOP
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("HIVE BASE (v" .. MANIFEST.base_version .. ")")
    print("Expecting Installer v" .. MANIFEST.installer_target)
    print("-----------------------------------")
    print("Waiting for Assignable Devices...")

    -- Wait for a packet
    local id, msg, proto = rednet.receive()

    if proto == "HIVE_DISCOVERY" and type(msg) == "table" and msg.type == "ASSIGNMENT_REQUEST" then
        local remote_ver = msg.payload.installer_version or "UNKNOWN"
        
        term.clear()
        term.setCursorPos(1,1)
        print("CONNECTION REQUEST: ID " .. id)
        print("Installer Version: " .. remote_ver)
        
        -- STRICT VERSION CHECK
        if remote_ver ~= MANIFEST.installer_target then
            term.setTextColor(colors.red)
            print("\n[!] VERSION MISMATCH [!]")
            print("Required: " .. MANIFEST.installer_target)
            print("Received: " .. remote_ver)
            print("\nConnection REFUSED. Please update the Factory Disk.")
            term.setTextColor(colors.white)
            print("\nPress any key to resume monitoring...")
            os.pullEvent("key")
        else
            -- VERSION MATCHED - PROCEED TO ASSIGNMENT
            term.setTextColor(colors.green)
            print("\nVersion Verified.")
            term.setTextColor(colors.white)
            print("Select Role for Device #" .. id .. ":")
            print("")
            
            -- Dynamic Menu based on MANIFEST
            local keys = {}
            local i = 1
            for role_name, _ in pairs(MANIFEST.roles) do
                print(" [" .. i .. "] " .. role_name)
                keys[tostring(i)] = role_name
                i = i + 1
            end
            print(" [X] Cancel")

            -- Input Loop
            local valid_choice = false
            while not valid_choice do
                local event, key = os.pullEvent("char")
                if key == "x" then 
                    valid_choice = true 
                    print("Cancelled.")
                elseif keys[key] then
                    valid_choice = true
                    provision_device(id, keys[key])
                end
            end
            
            sleep(2)
        end
    end
end