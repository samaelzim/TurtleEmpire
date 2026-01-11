-- ============================================================================
-- FILE: baseStartup.lua (HIVE COMMANDER DASHBOARD)
-- VERSION: 1.1.0  <-- We will change this number to test updates
-- ============================================================================

local CONFIG = {
    version   = "1.1.0 - BETA",
    modemSide = "top",
    repoDir   = "/repository/", -- Check if disk exists automatically later
    protocol  = "HIVE_V1"
}

-- DETECT DISK DRIVE
if fs.exists("/disk/repository/") then
    CONFIG.repoDir = "/disk/repository/"
end

-- UTILS: UI HELPERS
local w, h = term.getSize()
local function drawHeader()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()
    print(" HIVE MIND COMMANDER   v" .. CONFIG.version)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 2)
    term.write(string.rep("-", w))
end

local function log(msg, type)
    local col = colors.white
    if type == "ERR" then col = colors.red
    elseif type == "OK" then col = colors.green
    elseif type == "WARN" then col = colors.yellow end
    
    term.setTextColor(col)
    print("\n> " .. msg)
    term.setTextColor(colors.white)
end

-- 1. INITIALIZATION
term.clear()
drawHeader()

-- A. Network Check
term.setCursorPos(1, 3)
if peripheral.getType(CONFIG.modemSide) == "modem" then
    rednet.open(CONFIG.modemSide)
    log("Network ONLINE (" .. CONFIG.modemSide .. ")", "OK")
    log("Host ID: " .. os.getComputerID(), "OK")
else
    log("NO MODEM DETECTED on " .. CONFIG.modemSide, "ERR")
end

-- B. Repository Check
local repoFiles = fs.list(CONFIG.repoDir)
local fileCount = #repoFiles
if fileCount > 0 then
    log("Repository Loaded: " .. fileCount .. " files ready to deploy.", "OK")
else
    log("Repository EMPTY or Missing!", "WARN")
    log("Run 'installer' to fetch fleet software.", "WARN")
end

-- 2. MAIN COMMAND LOOP
print("\n[COMMAND LIST]")
print(" 'update' - Fetch new version from GitHub")
print(" 'scan'   - Ping for turtles")
print(" 'clear'  - Reset screen")

while true do
    term.setTextColor(colors.cyan)
    write("\nCMD> ")
    term.setTextColor(colors.white)
    
    local input = read()
    
    if input == "update" then
        if fs.exists("installer.lua") then
            log("Running Installer...", "WARN")
            sleep(1)
            shell.run("installer") -- This will reboot automatically on success
        else
            log("Installer missing! Download it manually.", "ERR")
        end
        
    elseif input == "scan" then
        log("Broadcasting Ping...", "WARN")
        rednet.broadcast({type="PING"}, CONFIG.protocol)
        -- In future, we listen for responses here
        
    elseif input == "clear" then
        term.clear()
        drawHeader()
        
    elseif input == "exit" or input == "reboot" then
        os.reboot()
        
    else
        log("Unknown Command.", "ERR")
    end
end