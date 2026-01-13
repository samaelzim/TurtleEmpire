-- ============================================================================
-- FILE: installer.lua
-- Role: GitHub Sync & Directory Structure Creator
-- Version: 1.2.1
-- ============================================================================

-- The base URL for your specific TurtleEmpire repository
local BASE_URL = "https://github.com/samaelzim/TurtleEmpire/raw/refs/heads/main/"

local FILES = {
    -- 1. Shared Libraries
    { url = BASE_URL .. "repo/lib/hive_net.lua",       path = "repo/lib/hive_net.lua" },
    { url = BASE_URL .. "repo/lib/turtle_move.lua",    path = "repo/lib/turtle_move.lua" },

    -- 2. Base Infrastructure (The Trio)
    { url = BASE_URL .. "repo/managers/base/archive_server.lua", path = "repo/managers/base/archive_server.lua" },
    { url = BASE_URL .. "repo/managers/base/brain_core.lua",     path = "repo/managers/base/brain_core.lua" },
    { url = BASE_URL .. "repo/managers/base/console_ui.lua",     path = "repo/managers/base/console_ui.lua" },

    -- 3. Mining Fleet Managers
    { url = BASE_URL .. "repo/managers/mining/startup.lua",      path = "repo/managers/mining/startup.lua" },

    -- 4. Mining Turtle Roles
    { url = BASE_URL .. "repo/roles/miner/startup.lua",          path = "repo/roles/miner/startup.lua" },
    
    -- 5. Utilities
    { url = BASE_URL .. "provision_disk.lua",                    path = "provision_disk.lua" }
}

local function download_file(url, path)
    -- Append cache-buster to ensure we get the latest version from GitHub
    local cache_buster_url = url .. "?cb=" .. os.time()
    print("Fetching: " .. path)
    
    local dir = path:match("(.*[/\\])")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local response = http.get(cache_buster_url)
    if not response then
        print("!! Failed to reach: " .. url)
        return false
    end

    local f = fs.open(path, "w")
    f.write(response.readAll())
    f.close()
    response.close()
    return true
end

-- MAIN EXECUTION
term.clear()
term.setCursorPos(1,1)
print("HIVE MIND UPDATER (v1.2.1)")
print("Source: samaelzim/TurtleEmpire")
print("---------------------------")

if not http then
    error("HTTP API is disabled in ComputerCraft config!")
end

local success_count = 0
print("Downloading " .. #FILES .. " files...")

for _, file_entry in ipairs(FILES) do
    -- Using .url and .path keys directly to fix nil concatenation error
    if download_file(file_entry.url, file_entry.path) then
        success_count = success_count + 1
    end
end

print("---------------------------")
print("Downloaded " .. success_count .. " / " .. #FILES .. " files.")

if success_count == #FILES then
    print("\nInstallation Complete.")
    print("Run this to set Archive startup:")
    print("cp repo/managers/base/archive_server.lua startup.lua")
else
    print("\nInstallation had errors. Check your internet/URL.")
end