-- ============================================================================
-- FILE: lumberjackStartup.lua
-- VERSION: 1.0.0
-- ============================================================================
local VERSION = "1.0.0"

-- 1. LOAD LIBRARY
if not fs.exists("lib/turtle_move.lua") then
    error("MISSING LIBRARY: lib/turtle_move.lua (Run installer!)")
end
local move = require("lib/turtle_move")

-- 2. SETUP
local PROTOCOL = "LUMBER_V1"
peripheral.find("modem", rednet.open)

-- UI Setup
term.clear()
term.setCursorPos(1,1)
print("LUMBERJACK UNIT v" .. VERSION)
print("Move Lib v" .. move.VERSION)
print("-------------------------")

-- 3. SMART INVENTORY DUMP
local function dumpInventory(dropoffPos)
    print("Unloading items...")
    move.goTo(dropoffPos.x, dropoffPos.y, dropoffPos.z)
    
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item then
            -- 1. Refuel Priority
            if item.name:find("coal") or item.name:find("charcoal") then
                turtle.refuel()
            
            -- 2. Keep Saplings (Do not drop)
            elseif item.name:find("sapling") then
                -- Do nothing, keep in inventory for replanting
            
            -- 3. Dump Everything Else (Logs, Sticks, Apples)
            else
                -- Assume chest is BELOW the dropoff coordinate
                turtle.dropDown() 
            end
        end
    end
end

-- 4. CHOP & REPLANT SEQUENCE
local function chopTree()
    -- Safety: Dig in front before moving in case of leaves/vines
    if turtle.detect() then turtle.dig() end
    
    -- Move into the trunk position
    if not turtle.forward() then 
        print("Blocked! Cannot enter tree.")
        return 
    end 

    -- CHOP UP
    while turtle.detectUp() do
        turtle.digUp()
        move.up()
    end
    
    -- COME DOWN
    while not turtle.detectDown() do
        move.down()
    end
    
    -- REPLANT LOGIC
    local saplingSlot = nil
    for i=1,16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find("sapling") then
            saplingSlot = i
            break
        end
    end
    
    move.updatePos("back")
    turtle.back() -- Step back out of the hole
    
    if saplingSlot then
        turtle.select(saplingSlot)
        turtle.place() -- Plant sapling in the hole we just left
        print("Replanted.")
    else
        print("No saplings to replant!")
    end
end

-- 5. MAIN LOOP
print("Acquiring GPS Lock...")
if not gps.locate() then
    error("NO GPS SIGNAL! Cannot operate.")
end
move.calibrate() -- Determine facing/position

while true do
    print("Requesting Job...")
    -- Send our version so Manager knows who we are
    rednet.broadcast({type="REQUEST_JOB", version=VERSION}, PROTOCOL)
    
    local id, job = rednet.receive(PROTOCOL, 5)
    
    if job and type(job) == "table" and job.type == "CHOP" then
        print("Job: Tree #" .. job.id)
        
        -- 1. Go to target (stop 1 block short in X to avoid collision?)
        -- Our current logic assumes we can walk into the adjacent square.
        -- We aim for: x-1, y, z (One block West of tree)
        move.goTo(job.target.x - 1, job.target.y, job.target.z)
        move.turnTo(1) -- Face East (towards tree)
        
        -- 2. Execute
        chopTree()
        
        -- 3. Check Inventory (Dump if full-ish)
        if turtle.getItemCount(16) > 0 then
            dumpInventory(job.dropoff)
        end
        
    elseif job == "WAIT" then
        print("Queue empty. Sleeping 10s...")
        sleep(10)
    else
        -- Timeout or garbage data
        sleep(1)
    end
end
