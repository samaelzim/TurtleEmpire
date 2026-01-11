-- ============================================================================
-- FILE: baseStartup.lua (COMMAND CENTER v4.0)
-- ============================================================================
local VERSION = "4.0.0"

local REPO_DIR = fs.exists("/disk/repository/") and "/disk/repository/" or "/repository/"
local PROTOCOL_UPDATE = "HIVE_UPDATE"
local PROTOCOL_OPS    = "HIVE_OPS"

local PACKAGES = {
    treeFarmManager = { startup = "treeFarmManagerStartup.lua", files = { "connection_test.lua" } },
    lumberjack      = { startup = "lumberjackStartup.lua",      files = { "lib/turtle_move.lua", "connection_test.lua" } },
    miner           = { startup = "minerStartup.lua",           files = { "lib/turtle_move.lua", "connection_test.lua" } }
}

-- SETUP
peripheral.find("modem", rednet.open)
local w, h = term.getSize()
local pendingTurtles = {}

-- UI HELPERS
local function drawHeader()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.clearLine()
    print(" HIVE COMMANDER v" .. VERSION .. " | REPO: " .. (fs.exists("disk") and "DISK" or "HDD"))
    term.setBackgroundColor(colors.black)
    print(string.rep("-", w))
end

-- A trick to print log messages without breaking the user input line
local function log(msg, color)
    local x, y = term.getCursorPos()
    term.setCursorPos(1, h-1) -- Go to line above prompt
    term.scroll(1) -- Push text up
    term.setCursorPos(1, h-1)
    term.clearLine()
    if color then term.setTextColor(color) end
    write("[LOG] " .. msg)
    term.setTextColor(colors.white)
    term.setCursorPos(x, y) -- Restore cursor for typing
end

-- ============================================================================
-- MAIN LOOP (Parallel Threads)
-- ============================================================================
term.clear()
drawHeader()
term.setCursorPos(1, h) -- Start prompt at bottom

parallel.waitForAny(
    -- THREAD 1: NETWORK LISTENER (Server)
    function()
        while true do
            local id, msg, proto = rednet.receive()
            
            -- 1. NEW DEVICE PING
            if proto == PROTOCOL_OPS and msg.type == "NEW_DEVICE" then
                if not pendingTurtles[msg.id] then
                    pendingTurtles[msg.id] = true
                    log("NEW DEVICE: ID #" .. msg.id, colors.yellow)
                    log("Type 'assign " .. msg.id .. " <role>'", colors.yellow)
                end
            
            -- 2. UPDATE REQUESTS
            elseif proto == PROTOCOL_UPDATE and msg.type == "REQ_UPDATE" then
                local role = msg.role
                log("Update Request: #" .. id .. " (" .. role .. ")", colors.cyan)
                
                local pkg = PACKAGES[role]
                if pkg then
                    -- Send Dependencies
                    if pkg.files then
                        for _, f in ipairs(pkg.files) do
                            local fObj = fs.open(REPO_DIR .. f, "r")
                            if fObj then
                                rednet.send(id, {type="FILE", path=f, content=fObj.readAll()}, PROTOCOL_UPDATE)
                                fObj.close()
                                sleep(0.1) 
                            end
                        end
                    end
                    -- Send Startup
                    local sObj = fs.open(REPO_DIR .. pkg.startup, "r")
                    if sObj then
                        rednet.send(id, {type="FILE", path="real_startup.lua", content=sObj.readAll()}, PROTOCOL_UPDATE)
                        sObj.close()
                    end
                    rednet.send(id, {type="DONE"}, PROTOCOL_UPDATE)
                    log("Deployment Complete: #" .. id, colors.green)
                else
                    log("Error: Unknown Role requested by #" .. id, colors.red)
                end
            end
        end
    end,

    -- THREAD 2: USER INPUT (Admin Dashboard)
    function()
        while true do
            term.setCursorPos(1, h)
            term.clearLine()
            term.write("CMD> ")
            local input = read()
            
            local args = {}
            for word in input:gmatch("%S+") do table.insert(args, word) end
            local cmd = args[1]

            if cmd == "update" then
                log("System Update Initiated...", colors.magenta)
                sleep(1)
                shell.run("installer") -- This reboots the system
                
            elseif cmd == "assign" then
                local tID = tonumber(args[2])
                local tRole = args[3]
                if tID and tRole and PACKAGES[tRole] then
                    log("Assigning " .. tRole .. " to #" .. tID, colors.green)
                    rednet.send(tID, { type = "ASSIGN_ROLE", role = tRole }, PROTOCOL_OPS)
                    pendingTurtles[tID] = nil
                else
                    log("Usage: assign <ID> <role>", colors.red)
                    log("Roles: lumberjack, miner, treeFarmManager", colors.gray)
                end
                
            elseif cmd == "clear" then
                term.clear()
                drawHeader()
                
            elseif cmd == "roles" then
                log("Available Roles:", colors.white)
                for k,v in pairs(PACKAGES) do log(" - " .. k) end
                
            elseif cmd == "scan" then
                log("Scanning Network...", colors.white)
                rednet.broadcast({type="PING"}, PROTOCOL_OPS)
                -- (Responses would need a handler in Thread 1)
                
            elseif cmd == "disk" then
                if fs.exists("provision_disk.lua") then
                    shell.run("provision_disk")
                else
                    log("Error: provision_disk.lua missing. Run 'update'.", colors.red)
                end

            elseif cmd == "exit" or cmd == "reboot" then
                os.reboot()
                
            else
                log("Unknown Command.", colors.red)
            end
        end
    end
)