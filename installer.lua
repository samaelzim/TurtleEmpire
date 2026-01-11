-- ============================================================================
-- FILE: installer.lua (MASTER SERVER SETUP)
-- ============================================================================

local BASE_URL = "https://raw.githubusercontent.com/samaelzim/TurtleEmpire/main/"
local REPO_DIR = "/repository/" -- Where we store files to serve to others

-- If a disk drive is attached, store the repo there for portability
if fs.exists("disk") then
    REPO_DIR = "/disk/repository/"
end

-- THE MANIFEST: Every file that exists in your project
local MANIFEST = {
    -- The Installer itself (so we can send it to new turtles)
    "installer.lua",
    "connection_test.lua",

    -- Library Files
    "lib/turtle_move.lua",

    -- Startup Files
    "baseStartup.lua",
    "minerStartup.lua",
    "lumberjackStartup.lua",
    "arboristStartup.lua",
    "farmerStartup.lua",
    "courierStartup.lua",
    "treeFarmManagerStartup.lua",
    "quarryManagerStartup.lua",
    "farmManagerStartup.lua",
    "courierManagerStartup.lua"
}

-- UTILITY: Download a single file
local function download(remoteName, localPath)
    local url = BASE_URL .. remoteName
    print("GET " .. remoteName)
    
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(localPath, "w")
        file.write(content)
        file.close()
        -- print(" [OK] Saved to " .. localPath) -- Keep it clean, only error on fail
    else
        print(" [ERR] 404 Not Found: " .. remoteName)
    end
end

-- EXECUTION
term.clear()
print("INITIALIZING HIVE MIND SERVER...")
print("Target Directory: " .. REPO_DIR)
print("--------------------------------")

-- 1. Create Repository Directory
if not fs.exists(REPO_DIR) then
    fs.makeDir(REPO_DIR)
end

-- 2. Download EVERYTHING into the repository folder
for _, filename in ipairs(MANIFEST) do
    download(filename, REPO_DIR .. filename)
end

-- 3. Install OUR OWN Brain (Base Station)
print("\nConfiguring Self...")
download("baseStartup.lua", "startup.lua")

print("\nServer Setup Complete.")
print("All fleet files stored in " .. REPO_DIR)
print("Rebooting in 3...")
sleep(3)
os.reboot()