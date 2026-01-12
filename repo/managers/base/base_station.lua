-- ============================================================================
-- HIVE BASE STATION (SERVER)
-- Location: repo/managers/base/base_station.lua
-- (Installer saves this to startup.lua on the Base Computer)
-- ============================================================================

-- THE MANIFEST: Single Source of Truth for Versions & Files
local MANIFEST = {
    system_name = "HIVE_BASE",
    base_version = "1.0.0",
    
    -- The Installer Version we expect incoming devices to have
    installer_target = "1.0.0",

    -- COMMON FILES (Sent to EVERYONE)
    common = {
        { "repo/lib/turtle_move.lua", "turtle_move.lua" },
        { "repo/lib/hive_net.lua",    "hive_net.lua" }
    },

    -- ROLE DEFINITIONS
    roles = {
        -- 1. WORKERS
        MINER = {
            version = "1.0.0",
            files = {
                { "repo/roles/miner/startup.lua", "startup.lua" }
                -- Add miner specific libs here later, e.g., dig_logic.lua
            }
        },
        LUMBERJACK = {
            version = "1.0.0",
            files = {
                { "repo/roles/lumberjack/startup.lua", "startup.lua" }
            }
        },
        FARMER = {
            version = "1.0.0",
            files = {
                { "repo/roles/farmer/startup.lua", "startup.lua" }
            }
        },
        COURIER = {
            version = "1.0.0",
            files = {
                { "repo/roles/courier/startup.lua", "startup.lua" }
            }
        },

        -- 2. MANAGERS
        MANAGER_MINING = {
            version = "1.0.0",
            files = {
                { "repo/managers/mining/startup.lua", "startup.lua" }
            }
        },
        MANAGER_FORESTRY = {
            version = "1.0.0",
            files = {
                { "repo/managers/forestry/startup.lua", "startup.lua" }
            }
        },
        MANAGER_FARMING = {
            version = "1.0.0",
            files = {
                { "repo/managers/farming/startup.lua", "startup.lua" }
            }
        },
        MANAGER_COURIER = {
            version = "1.0.0",
            files = {
                { "repo/managers/courier/startup.lua", "startup.lua" }
            }
        }
    }
}

-- 2. SETUP NETWORK
peripheral.find("modem", rednet.open)
rednet.host("HIVE_DISCOVERY", "base_station_1")

-- 3. HELPER: FILE SENDER
local function send_file(target_id, source_path, dest_name, version_tag)
    if not fs.exists(source_path) then
        print(" [ERR] Missing File: " .. source_path)
        return false
    end

    local f = fs.open(source_path, "r")
    local content = f.readAll()
    f.close()

    -- INJECT VERSION (Only for startup files)
    if dest_name == "startup.lua" and version_tag then
        local header = "local VERSION = '" .. version_tag .. "'\n"
        content = header .. content
    end

    rednet.send(target_id, {
        type     = "FILE_PUSH",
        filename = dest_name,
        content  = content
    }, "HIVE_V1")
    
    return true
end

-- 4. HELPER: PROVISIONING SEQUENCE
local function provision_device(target_id, role_key)
    local role_data = MANIFEST.roles[role_key]
    if not role_data then return end

    print(" >> Deploying " .. role_key .. " (v" .. role_data.version .. ") to #" .. target_id)

    -- A. SEND COMMON FILES
    for _, file_def in ipairs(MANIFEST.common) do
        send_file(target_id, file_def[1], file_def[2])
        sleep(0.1) -- Throttle network
    end

    -- B. SEND ROLE FILES
    for _, file_def in ipairs(role_data.files) do
        send_file(target_id, file_def[1], file_def[2], role_data.version)
        sleep(0.1)
    end

    -- C. SEND MANAGER CONFIG (Placeholder for now)
    -- This creates a tiny file .manager containing ID "0"
    rednet.send(target_id, {
        type = "FILE_PUSH",
        filename = ".manager",
        content = "0"
    }, "HIVE_V1")

    -- D. REBOOT
    sleep(1)
    rednet.send(target_id, { type = "REBOOT" }, "HIVE_V1")
    print(" >> Provisioning Complete.")
end

-- 5. MAIN SERVER LOOP
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("HIVE BASE STATION (v" .. MANIFEST.base_version .. ")")
    print("-----------------------------------")
    print("Waiting for Assignment Requests...")

    local id, msg, proto = rednet.receive()

    -- Check for valid HIVE packet
    if proto == "HIVE_DISCOVERY" and type(msg) == "table" and msg.type == "ASSIGNMENT_REQUEST" then
        local device_ver = msg.payload.installer_version or "UNKNOWN"
        local hardware   = msg.payload.hardware or "UNKNOWN" -- (Optional: Add hardware type to installer later)

        term.clear()
        term.setCursorPos(1,1)
        print("CONNECTION REQUEST: ID " .. id)
        print("Installer Version: " .. device_ver)

        if device_ver ~= MANIFEST.installer_target then
            -- VERSION MISMATCH
            term.setTextColor(colors.red)
            print("\n[!] VERSION MISMATCH [!]")
            print("Required: " .. MANIFEST.installer_target)
            print("Received: " .. device_ver)
            term.setTextColor(colors.white)
            print("\nPress key to ignore...")
            os.pullEvent("key")
        else
            -- VALID CONNECTION -> MENU
            term.setTextColor(colors.green)
            print("\nVerified. Select Role:")
            term.setTextColor(colors.white)

            local keys = {}
            local i = 1
            -- Sort roles alphabetically for consistent menu
            local sorted_roles = {}
            for k in pairs(MANIFEST.roles) do table.insert(sorted_roles, k) end
            table.sort(sorted_roles)

            for _, role_name in ipairs(sorted_roles) do
                print(" [" .. i .. "] " .. role_name)
                keys[tostring(i)] = role_name
                i = i + 1
            end
            print(" [X] Cancel")

            -- Input Loop
            local chosen = false
            while not chosen do
                local _, key = os.pullEvent("char")
                if key == "x" then 
                    chosen = true 
                elseif keys[key] then
                    chosen = true
                    provision_device(id, keys[key])
                end
            end
        end
    end
end