-- ============================================================================
-- FACTORY SCRIPT: WRITES THE "BEACON" INSTALLER TO A FLOPPY DISK
-- Usage: Run on a computer with a Disk Drive.
-- ============================================================================

local INSTALLER_VERSION = "1.0.0"

if not fs.exists("disk") then
    error("No Disk Drive found! Please insert a floppy disk.")
end

print("provisioning disk with BEACON installer v" .. INSTALLER_VERSION)

-- We split the string here to inject the version number.
local disk_firmware_header = "local VERSION = '" .. INSTALLER_VERSION .. "'\n"
local disk_firmware_body = [[
-- BEACON INSTALLER (Runs from Disk)

-- 1. SAFETY CHECK: PREVENT ACCIDENTAL WIPES
if fs.exists("startup.lua") then
    term.clear()
    term.setCursorPos(1,1)
    print("EXISTING OS DETECTED.")
    print("Press 'r' within 2 seconds to RE-PROVISION.")
    print("Otherwise, booting Hard Drive...")

    local timer = os.startTimer(2)
    local event, p1 = os.pullEvent()

    if event == "char" and p1 == "r" then
        print(" > Wiping & Re-provisioning...")
        sleep(0.5)
    else
        -- Timeout or other key pressed: Boot the Hard Drive
        shell.run("startup.lua")
        return -- Stop this script so we don't continue below
    end
end

-- 2. SETUP NETWORK
print("Initializing Network...")
peripheral.find("modem", rednet.open)

local myID = os.getComputerID()
print("ID: " .. myID)

-- 3. BROADCAST REQUEST
local request_packet = {
    protocol = "HIVE_V1",
    senderID = myID,
    targetID = -1,
    role     = "NULL",
    type     = "ASSIGNMENT_REQUEST",
    payload  = {
        installer_version = VERSION
    }
}

print("Contacting Base...")
rednet.broadcast(request_packet, "HIVE_DISCOVERY")

-- 4. INSTALLATION LOOP (The "Listening" Phase)
print("Waiting for files...")

while true do
    -- Wait for a message from the Base
    local sender, msg = rednet.receive()

    -- Verify it's a valid HIVE packet
    if type(msg) == "table" and msg.protocol == "HIVE_V1" then
        
        -- TYPE A: INCOMING FILE
        if msg.type == "FILE_PUSH" then
            local fname = msg.filename
            local fcontent = msg.content
            
            print("Downloading: " .. fname)
            
            -- Open file for writing (creates it if missing)
            local f = fs.open(fname, "w")
            f.write(fcontent)
            f.close()

        -- TYPE B: REBOOT COMMAND (Installation Complete)
        elseif msg.type == "REBOOT" then
            print("Installation Complete.")
            print("Rebooting in 3 seconds...")
            sleep(3)
            os.reboot()
        end
    end
end
]]

-- COMBINE HEADER + BODY
local full_code = disk_firmware_header .. disk_firmware_body

-- WRITE THE FILE TO THE DISK
local f = fs.open("disk/startup.lua", "w")
f.write(full_code)
f.close()

print("Factory Disk (v" .. INSTALLER_VERSION .. ") Ready!")