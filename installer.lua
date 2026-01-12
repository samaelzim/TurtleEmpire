-- ============================================================================
-- FILE: installer.lua (SYSTEM UPDATER)
-- Usage: Run on Base Computer to pull latest Hive Mind version
-- ============================================================================

local INSTALLER_VERSION = "1.0.0" 
local BASE_URL = "https://raw.githubusercontent.com/samaelzim/TurtleEmpire/main/"

-- ============================================================================
-- 1. CONFIGURATION
-- ============================================================================

local FILES = {
    -- A. SYSTEM FILES (Root)
    -- We grab the base station code from its folder but save it as the main startup
    { remote = "repo/managers/base/base_station.lua", path = "startup.lua" },        
    { remote = "provision_disk.lua",                  path = "provision_disk.lua" }, 
    { remote = "installer.lua",                       path = "installer.lua" }, -- Self-Update

    -- B. LIBRARIES (Shared Code)
    { remote = "repo/lib/turtle_move.lua",            path = "repo/lib/turtle_move.lua" },
    { remote = "repo/lib/hive_net.lua",              path = "repo/lib/hive_net.lua" },

    -- C. MANAGERS
    { remote = "repo/managers/mining/startup.lua",    path = "repo/managers/mining/startup.lua" },
    { remote = "repo/managers/forestry/startup.lua",  path = "repo/managers/forestry/startup.lua" },
    { remote = "repo/managers/farming/startup.lua",   path = "repo/managers/farming/startup.lua" },
    { remote = "repo/managers/courier/startup.lua",   path = "repo/managers/courier/startup.lua" },

    -- D. ROLES
    { remote = "repo/roles/miner/startup.lua",        path = "repo/roles/miner/startup.lua" },
    { remote = "repo/roles/lumberjack/startup.lua",   path = "repo/roles/lumberjack/startup.lua" },
    { remote = "repo/roles/farmer/startup.lua",       path = "repo/roles/farmer/startup.lua" },
    { remote = "repo/roles/courier/startup.lua",      path = "repo/roles/courier/startup.lua" },
}

-- ============================================================================
-- 2. UTILITY FUNCTIONS
-- ============================================================================

local function download_file(remote_path, local_path)
    local url = BASE_URL .. remote_path
    write("GET " .. remote_path .. " ... ")
    
    local response = http.get(url)
    
    if response then
        -- 1. Create the directory if it doesn't exist
        if local_path:find("/") then
            local dir = local_path:sub(1, local_path:find("/[^/]*$")-1)
            if not fs.exists(dir) then fs.makeDir(dir) end
        end

        -- 2. Write the file
        local f = fs.open(local_path, "w")
        f.write(response.readAll())
        f.close()
        response.close()
        print("OK")
    else
        print("FAIL (404)")
        print(" -> URL: " .. url)
    end
end

-- ============================================================================
-- 3. MAIN EXECUTION
-- ============================================================================

term.clear()
term.setCursorPos(1,1)
print("HIVE MIND UPDATER (v" .. INSTALLER_VERSION .. ")")
print("Source: GitHub Main Branch")
print("-----------------------------------")

-- CLEANUP: Remove old repository to prevent version conflicts
if fs.exists("repo") then
    print("Cleaning old repository cache...")
    fs.delete("repo")
end

-- DOWNLOAD LOOP
print("Downloading " .. #FILES .. " files...")

for _, file_def in ipairs(FILES) do
    download_file(file_def.remote, file_def.path)
end

print("-----------------------------------")
print("Update Complete.")
print("Rebooting in 3 seconds...")
sleep(3)
os.reboot()