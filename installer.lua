-- ============================================================================
-- FILE: installer.lua
-- Role: GitHub Sync & Directory Structure Creator
-- Version: 1.2.1
-- ============================================================================

-- CHANGE THIS to your actual raw GitHub path
local BASE_URL = "https://raw.githubusercontent.com/YourUsername/YourRepo/main/"

local FILES = {
    -- Libraries
    { url = BASE_URL .. "repo/lib/hive_net.lua",       path = "repo/lib/hive_net.lua" },
    { url = BASE_URL .. "repo/lib/turtle_move.lua",    path = "repo/lib/turtle_move.lua" },

    -- Base Infrastructure
    { url = BASE_URL .. "repo/managers/base/archive_server.lua", path = "repo/managers/base/archive_server.lua" },
    { url = BASE_URL .. "repo/managers/base/brain_core.lua",     path = "repo/managers/base/brain_core.lua" },
    { url = BASE_URL .. "repo/managers/base/console_ui.lua",     path = "repo/managers/base/console_ui.lua" },

    -- Mining Fleet
    { url = BASE_URL .. "repo/managers/mining/startup.lua",      path = "repo/managers/mining/startup.lua" },
    { url = BASE_URL .. "repo/roles/miner/startup.lua",          path = "repo/roles/miner/startup.lua" },
    
    -- Utilities
    { url = BASE_URL .. "provision_disk.lua",                    path = "provision_disk.lua" }
}

local function download_file(url, path)
    print("Fetching: " .. path)
    
    -- Create directory if it doesn't exist
    local dir = path:match("(.*[/\\])")
    if dir and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local response = http.get(url)
    if not response then
        print("!! Failed: " .. url)
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
print("HIVE INSTALLER v1.2.1")
print("Source: GitHub Main Branch")
print("---------------------------")

if not http then
    error("HTTP API is disabled in ComputerCraft config!")
end

local success_count = 0
for _, file_entry in ipairs(FILES) do
    -- We use file_entry.url and file_entry.path to match the table keys
    if download_file(file_entry.url, file_entry.path) then
        success_count = success_count + 1
    end
end

print("---------------------------")
print("Downloaded " .. success_count .. " / " .. #FILES .. " files.")

if success_count == #FILES then
    print("\nInstallation Complete.")
    print("To start Archive on boot, run:")
    print("cp repo/managers/base/archive_server.lua startup.lua")
else
    print("\nInstallation had errors. Check your BASE_URL.")
end