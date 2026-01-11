-- ============================================================================
-- FILE: installer.lua (BASE STATION REPO SYNC)
-- Usage: Run only on the Base Computer with Internet
-- ============================================================================

local BASE_URL = "https://raw.githubusercontent.com/samaelzim/TurtleEmpire/main/"
local REPO_DIR = "/disk/repository/" -- Stores files here to serve to turtles

-- If no disk drive, fall back to local storage (but Disk is better for portability)
if not fs.exists("disk") then
    REPO_DIR = "/repository/"
    print("[WARN] No Disk Drive found. Saving to local /repository/")
end

-- MASTER MANIFEST: Every file that exists on GitHub
local MANIFEST = {
    "baseStartup.lua",
    "treeFarmManagerStartup.lua",
    "lumberjackStartup.lua",
    "minerStartup.lua",
    "lib/turtle_move.lua",
    "connection_test.lua",
    "update_client.lua" -- NEW: The script turtles use to ask for updates
}

-- 1. UTILITY: Download Helper
local function download(remote, localPath)
    local url = BASE_URL .. remote
    print("GET " .. remote)
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        -- Create subfolders if needed
        if localPath:find("/") then
            local dir = localPath:sub(1, localPath:find("/[^/]*$")-1)
            if not fs.exists(dir) then fs.makeDir(dir) end
        end

        local file = fs.open(localPath, "w")
        file.write(content)
        file.close()
    else
        print(" [ERR] 404 Not Found: " .. remote)
    end
end

-- 2. EXECUTION
term.clear()
print("SYNCING REPOSITORY FROM GITHUB...")
print("Target: " .. REPO_DIR)
print("---------------------------------")

if not fs.exists(REPO_DIR) then fs.makeDir(REPO_DIR) end

-- Download Fleet Files
for _, file in ipairs(MANIFEST) do
    download(file, REPO_DIR .. file)
end

-- Update Base Station's own startup
print("\nUpdating Base Station Firmware...")
download("baseStartup.lua", "startup.lua")

print("\nSync Complete. Rebooting...")
sleep(2)
os.reboot()