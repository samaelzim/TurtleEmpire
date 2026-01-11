-- ============================================================================
-- FILE: provision_disk.lua (FACTORY DISK CREATOR)
-- Usage: Run this once to create the "Magic Boot Disk"
-- ============================================================================

if not fs.exists("disk") then
    error("No Disk Drive found! Please insert a floppy disk.")
end

print("Writing Factory Firmware to Disk...")

-- This is the code that stays ON THE DISK
-- It runs automatically when a new turtle boots with the disk inserted
local diskStartup = [[
-- FACTORY INSTALLER
term.clear()
term.setCursorPos(1,1)
print("INITIALIZING FACTORY NEW UNIT...")

-- 1. DEFINE THE CLIENT LISTENER CODE
-- (This is the logic that gets saved to the Turtle's Hard Drive)
local clientFirmware = [=[
local PROTOCOL_OPS = "HIVE_OPS"
local PROTOCOL_UPDATE = "HIVE_UPDATE"
local ROLE_FILE = ".role"
local REPO_DIR = "disk/repository/" -- Fallback if we have a disk

-- WAIT FOR PERIPHERALS
print("HIVE LINK: WAITING FOR NETWORK...")
while not peripheral.find("modem", rednet.open) do
    sleep(1)
end

-- MAIN LOOP
term.clear()
term.setCursorPos(1,1)
print("ID: " .. os.getComputerID())
print("STATUS: UNASSIGNED - CONTACTING SERVER")

while true do
    -- 1. PING SERVER
    rednet.broadcast({
        type = "NEW_DEVICE",
        id = os.getComputerID()
    }, PROTOCOL_OPS)
    
    -- 2. WAIT FOR ASSIGNMENT
    local senderId, msg = rednet.receive(PROTOCOL_OPS, 5)
    
    if msg and type(msg) == "table" and msg.type == "ASSIGN_ROLE" then
        local role = msg.role
        print("\n[+] ASSIGNED ROLE: " .. role)
        
        -- Save Role
        local f = fs.open(ROLE_FILE, "w")
        f.write(role)
        f.close()
        
        -- REQUEST DOWNLOAD
        print("Downloading Firmware...")
        rednet.broadcast({ type = "REQ_UPDATE", role = role }, PROTOCOL_UPDATE)
        
        -- RECEIVE FILES LOOP
        while true do
            local _, uMsg = rednet.receive(PROTOCOL_UPDATE)
            if uMsg and uMsg.type == "FILE" then
                print(" -> " .. uMsg.path)
                if uMsg.path:find("/") then fs.makeDir(fs.getDir(uMsg.path)) end
                local f = fs.open(uMsg.path, "w")
                f.write(uMsg.content)
                f.close()
                
                if uMsg.path == "real_startup.lua" then
                   -- We use a temp name so we don't crash while running
                   fs.move("real_startup.lua", "startup.lua")
                end
            elseif uMsg and uMsg.type == "DONE" then
                print("FIRMWARE INSTALLED. REBOOTING.")
                sleep(2)
                os.reboot()
            end
        end
    end
    sleep(3)
end
]=]

-- 2. INSTALL TO HARD DRIVE
print("Flashing EEPROM...")
if fs.exists("startup.lua") then
    fs.delete("startup.lua") -- Wipe old data
end

local f = fs.open("startup.lua", "w")
f.write(clientFirmware)
f.close()

-- 3. SIGNAL SUCCESS
term.setBackgroundColor(colors.green)
term.setTextColor(colors.black)
term.clear()
term.setCursorPos(1, 2)
print("  PROVISIONING COMPLETE  ")
print("  REMOVE TURTLE NOW      ")
print("  (ID: " .. os.getComputerID() .. ")")
textutils.slowPrint(".........................")
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
os.pullEvent("key") -- Wait for user to acknowledge or just break it
os.shutdown()
]]

-- WRITE TO DISK
local f = fs.open("disk/startup.lua", "w")
f.write(diskStartup)
f.close()

print("Success! The Factory Disk is ready.")
print("Place a new turtle next to the drive and turn it on.")