-- ============================================================================
-- FILE: installer.lua (SYSTEM UPDATER)
-- Usage: Run on Base Computer to pull latest Hive Mind version
-- ============================================================================

local INSTALLER_VERSION = "1.1.0" 
local BASE_URL = "https://raw.githubusercontent.com/samaelzim/TurtleEmpire/main/"

-- ============================================================================
-- 1. CONFIGURATION
-- ============================================================================

local FILES = {
    -- 1. Shared Libraries
    { url = BASE_URL .. "repo/lib/hive_net.lua",       path = "repo/lib/hive_net.lua" },
    { url = BASE_URL .. "repo/lib/turtle_move.lua",    path = "repo/lib/turtle_move.lua" },

    -- 2. Base Infrastructure (The Trio)
    { url = BASE_URL .. "repo/managers/base/archive_server.lua", path = "startup.lua" },
    { url = BASE_URL .. "repo/managers/base/brain_core.lua",     path = "repo/managers/base/brain_core.lua" },
    { url = BASE_URL .. "repo/managers/base/console_ui.lua",     path = "repo/managers/base/console_ui.lua" },

    -- 3. Mining Fleet Managers
    { url = BASE_URL .. "repo/managers/mining/startup.lua",      path = "repo/managers/mining/startup.lua" },

    -- 4. Mining Turtle Roles
    { url = BASE_URL .. "repo/roles/miner/startup.lua",          path = "repo/roles/miner/startup.lua" },
    
    -- 5. Utility Scripts
    { url = BASE_URL .. "provision_disk.lua",                    path = "provision_disk.lua" }
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