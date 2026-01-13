-- ============================================================================
-- FILE: provision_disk.lua
-- Role: Universal Provisioning Disk Creator
-- Version: 1.2.1
-- ============================================================================
local DISK_VERSION = "1.2.1"

if not fs.exists("disk") then 
    error("No disk found! Insert a floppy into the drive.") 
end

print("Preparing Hive Provisioning Disk v" .. DISK_VERSION)

-- 1. Create the Bootstrap Startup File on the Floppy
local h = fs.open("disk/startup.lua", "w")
h.write([[
    -- Bootstrap code runs on the NEW computer from the floppy
    local BOOT_VERSION = "]]..DISK_VERSION..[["
    local PROTOCOL = "HIVE_PROT_V1"
    
    term.clear()
    term.setCursorPos(1,1)
    print("HIVE BOOTSTRAP v" .. BOOT_VERSION)
    print("Device ID: " .. os.getComputerID())
    print("---------------------------")

    -- Initialize Modem
    local modem = peripheral.find("modem")
    if not modem then error("No modem detected!") end
    rednet.open(peripheral.getName(modem))

    print("Searching for HIVE_ARCHIVE...")
    
    while true do
        local archiveID = rednet.lookup(PROTOCOL, "HIVE_ARCHIVE")
        
        if archiveID then
            -- Signal the Archive that we are ready for a role assignment
            rednet.send(archiveID, {type = "DISCOVERY_PING", payload = {v = BOOT_VERSION}}, PROTOCOL)
            
            -- Listen for Incoming Files or Commands
            local sender, msg = rednet.receive(PROTOCOL, 5)
            
            if msg then
                -- Send ACK back for reliable delivery
                rednet.send(sender, {type = "ACK", payload = {}}, PROTOCOL)

                if msg.type == "FILE_TRANSFER" then
                    print("Downloading: " .. msg.payload.name)
                    local f = fs.open(msg.payload.name, "w")
                    f.write(msg.payload.content)
                    f.close()
                elseif msg.type == "COMMAND" and msg.payload.cmd == "REBOOT" then
                    print("Deployment Successful.")
                    print("EJECT DISK NOW!")
                    sleep(3)
                    os.reboot()
                end
            end
        else
            print("Archive not found. Retrying...")
            sleep(2)
        end
    end
]])
h.close()

-- 2. Label the disk so you don't lose it
local drive = peripheral.find("drive")
if drive then
    drive.setDiskLabel("HIVE_PROVISION_v" .. DISK_VERSION)
end

print("Done! Use this disk to set up your Brain and Console.")