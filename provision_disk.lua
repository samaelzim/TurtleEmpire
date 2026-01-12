-- ============================================================================
-- FACTORY SCRIPT: WRITES THE "BEACON" INSTALLER TO A FLOPPY DISK
-- Usage: Run on the Base Computer with a Disk Drive attached.
-- ============================================================================

local INSTALLER_VERSION = "1.0.0"

-- 1. FIND THE DISK
if not fs.exists("disk") then
    error("No Disk Drive found! Please insert a floppy disk.")
end

print("Provisioning Disk with Installer v" .. INSTALLER_VERSION .. "...")

-- 2. COPY THE LIBRARY (CRITICAL STEP)
-- We must put hive_net.lua on the disk so the Turtle can use it!
if fs.exists("disk/hive_net.lua") then
    fs.delete("disk/hive_net.lua")
end

if fs.exists("repo/lib/hive_net.lua") then
    fs.copy("repo/lib/hive_net.lua", "disk/hive_net.lua")
    print(">> Copied hive_net.lua to disk.")
else
    error("CRITICAL: 'repo/lib/hive_net.lua' is missing on the Base!")
end

-- 3. WRITE THE INSTALLER CODE
local h = fs.open("disk/startup.lua", "w")

h.write([[
-- TURTLE INSTALLER v]]..INSTALLER_VERSION..[[
-- Force Lua to look on the disk for the library
package.path = package.path .. ";disk/?.lua"

local net = require("hive_net")
local osID = os.getComputerID()

term.clear()
print("HIVE MIND INSTALLER v]]..INSTALLER_VERSION..[[")
print("---------------------------")
print("Initializing Network...")

if not net.init() then
    print("Error: No Wireless Modem found!")
    return
end

print("ID: " .. osID)
print("Contacting Base...")

while true do
    -- HANDSHAKE: Send "DISCOVERY_PING" (Matches Base Station)
    net.send("HIVE_DISCOVERY", "DISCOVERY_PING", { 
        version = "]]..INSTALLER_VERSION..[[" 
    })
    
    print(">> Ping sent. Waiting for reply...")
    
    -- Wait 3 seconds for a reply
    local msg, sender = net.receive(nil, nil, 3)
    
    -- HANDLE FILE TRANSFERS
    if msg and msg.type == "FILE_TRANSFER" then
        print(">> Connection Established with Base #"..sender)
        print(">> Receiving: " .. msg.payload.name)
        
        local f = fs.open(msg.payload.name, "w")
        f.write(msg.payload.content)
        f.close()
        
    -- HANDLE REBOOT COMMAND
    elseif msg and msg.type == "COMMAND" and msg.payload.cmd == "REBOOT" then
        print(">> Installation Complete. Rebooting...")
        sleep(1)
        os.reboot()
    end
    
    sleep(2)
end
]])

h.close()

print("Factory Disk (v" .. INSTALLER_VERSION .. ") Created.")
print("1. Insert into Turtle.")
print("2. Reboot Turtle.")