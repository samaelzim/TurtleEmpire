-- ============================================================================
-- FILE: baseStartup.lua (FLEET COMMANDER)
-- VERSION: 3.0.0
-- ============================================================================
local VERSION = "3.0.0"

local REPO_DIR = fs.exists("/disk/repository/") and "/disk/repository/" or "/repository/"
local PROTOCOL_UPDATE = "HIVE_UPDATE"
local PROTOCOL_OPS    = "HIVE_OPS"

-- ROLE DEFINITIONS
local PACKAGES = {
    treeFarmManager = { startup = "treeFarmManagerStartup.lua", files = { "connection_test.lua" } },
    lumberjack      = { startup = "lumberjackStartup.lua",      files = { "lib/turtle_move.lua", "connection_test.lua" } },
    miner           = { startup = "minerStartup.lua",           files = { "lib/turtle_move.lua", "connection_test.lua" } }
}

-- SETUP
peripheral.find("modem", rednet.open)
term.clear()

local function log(msg) print("["..os.time().."] " .. msg) end
local pendingTurtles = {} -- List of turtles asking for roles

print("BASE STATION v" .. VERSION)
print("Listening for fleet...")

while true do
    -- Non-blocking input (so we can listen and type at the same time)
    parallel.waitForAny(
        -- TASK 1: NETWORK LISTENER
        function()
            local id, msg, proto = rednet.receive()
            
            -- A. NEW TURTLE DISCOVERED
            if proto == PROTOCOL_OPS and msg.type == "NEW_DEVICE" then
                if not pendingTurtles[msg.id] then
                    pendingTurtles[msg.id] = true
                    term.setTextColor(colors.yellow)
                    print("\n[!] NEW DEVICE DETECTED: ID #" .. msg.id)
                    print("    Type 'assign " .. msg.id .. " <role>' to configure.")
                    term.setTextColor(colors.white)
                    write("> ")
                end
            
            -- B. UPDATE REQUESTS (Standard File Server)
            elseif proto == PROTOCOL_UPDATE and msg.type == "REQ_UPDATE" then
                local role = msg.role
                log("Serving update ("..role..") to #"..id)
                
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
                end
            end
        end,

        -- TASK 2: USER INPUT (Assign Roles)
        function()
            write("> ")
            local input = read()
            local args = {}
            for word in input:gmatch("%S+") do table.insert(args, word) end
            
            if args[1] == "assign" then
                local tID = tonumber(args[2])
                local tRole = args[3]
                
                if tID and tRole and PACKAGES[tRole] then
                    print("Assigning " .. tRole .. " to #" .. tID .. "...")
                    rednet.send(tID, {
                        type = "ASSIGN_ROLE",
                        role = tRole
                    }, PROTOCOL_OPS)
                    pendingTurtles[tID] = nil -- Clear pending flag
                else
                    print("Error: Invalid ID or Unknown Role.")
                    print("Roles: lumberjack, miner, treeFarmManager")
                end
            elseif args[1] == "roles" then
                for k,v in pairs(PACKAGES) do print("- "..k) end
            end
        end
    )
end