-- ============================================================================
-- FILE: archive_server.lua
-- Role: Master OTA File Server
-- Version: 1.3.0
-- ============================================================================
package.path = package.path .. ";repo/lib/?.lua"
local net = require("hive_net")

local MANIFEST = {
    common = { { "repo/lib/hive_net.lua", "hive_net.lua" } },
    system = {
        HIVE_BRAIN   = { { "repo/managers/base/brain_core.lua", "startup.lua" } },
        HIVE_CONSOLE = { { "repo/managers/base/console_ui.lua", "startup.lua" } },
    },
    fleet = {        
        MINER_TURTLE  = { 
            { "repo/lib/turtle_move.lua", "turtle_move.lua" },
            { "repo/roles/miner/startup.lua", "startup.lua" } 
        },
        MINER_MANAGER = { { "repo/managers/mining/startup.lua", "startup.lua" } }
    }
}

local function push_update(target_id, role)
    local files = {}
    for _, f in ipairs(MANIFEST.common) do table.insert(files, f) end
    
    local role_files = MANIFEST.system[role] or MANIFEST.fleet[role]
    if role_files then
        for _, f in ipairs(role_files) do table.insert(files, f) end
    end

    for _, fileData in ipairs(files) do
        local f = fs.open(fileData[1], "r")
        local content = f.readAll()
        f.close()
        net.send_safe(target_id, "OTA_UPDATE", { name = fileData[2], content = content })
    end
    net.send(target_id, "COMMAND", { cmd = "REBOOT" })
end

net.init()
rednet.host("HIVE_PROT_V1", "HIVE_ARCHIVE")
print("Archive OTA Server Online")

while true do
    local msg, sender = net.receive()
    if msg then
        net.send(sender, "ACK")
        
        -- Check for Version requests on reboot
        if msg.type == "CHECK_UPDATE" then
            print("Update Check: ID " .. sender)
            push_update(sender, msg.payload.role)
            
        -- Manual Command from Console/Terminal
        elseif msg.type == "FORCE_OTA" then
            if msg.payload.id == "ALL" then
                -- Broadcast update logic would go here
            else
                push_update(msg.payload.id, msg.payload.role)
            end
        end
    end
end