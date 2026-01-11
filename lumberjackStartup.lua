-- ============================================================================
-- FILE: lumberjackStartup.lua
-- ============================================================================

-- 1. LOAD LIBRARY
if not fs.exists("lib/turtle_move.lua") then
    error("MISSING LIBRARY: lib/turtle_move.lua")
end
local move = require("lib/turtle_move")

-- 2. SETUP
local PROTOCOL = "LUMBER_V1"
peripheral.find("modem", rednet.open)

-- 3. INVENTORY DUMP (Improved)
local function dumpInventory(dropoffPos)
    print("Unloading...")
    -- Go to the chest coordinates
    move.goTo(dropoffPos.x, dropoffPos.y, dropoffPos.z)
    
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item then
            -- Refuel with Coal/Charcoal
            if item.name:find("coal") or item.name:find("charcoal") then
                turtle.refuel()
            -- Keep Saplings (Example: oak_sapling)
            elseif item.name:find("sapling") then
                -- Keep max 10 saplings, drop rest?
                -- For now, just keep them to replant
            else
                -- Drop Logs/Sticks into chest (Front/Down depending on setup)
                -- We assume chest is BELOW the dropoff coordinate
                turtle.dropDown() 
            end
        end
    end
end

local function chopTree()
    -- Assume we are standing exactly ON the tree coordinate
    -- We need to dig the block we are standing in? No, usually adjacent.
    -- Let's assume goTo() puts us ADJACENT to the target.
    
    -- Dig Forward (Trunk base)
    if turtle.detect() then turtle.dig() end
    if not turtle.forward() then return end -- Move into trunk space

    -- Chop Up
    while turtle.detectUp() do
        turtle.digUp()
        move.up()
    end
    
    -- Come Down
    while not turtle.detectDown() do
        move.down()
    end
    
    -- REPLANT (If we have saplings)
    local saplingSlot = nil
    for i=1,16 do
        local item = turtle.getItemDetail(i)
        if item and item.name:find("sapling") then
            saplingSlot = i
            break
        end
    end
    
    if saplingSlot then
        turtle.select(saplingSlot)
        -- Move back out of the hole
        move.updatePos("back")
        turtle.back()
        -- Place sapling in front
        turtle.place()
    else
        move.updatePos("back")
        turtle.back()
    end
end

-- 4. MAIN LOOP
print("Initializing Lumberjack...")
if not gps.locate() then
    error("NO GPS SIGNAL! Cannot operate.")
end
move.calibrate() -- Lock in our starting position

while true do
    print("Requesting Job...")
    rednet.broadcast("REQUEST_JOB", PROTOCOL)
    
    local id, job = rednet.receive(PROTOCOL, 5)
    
    if job and type(job) == "table" and job.type == "CHOP" then
        print("Job: Tree #" .. job.id .. " at " .. job.target.x .. "," .. job.target.z)
        
        -- 1. Travel to Tree
        -- (Ideally, stop 1 block away so we don't crash into it)
        -- Simple fix: Go to Y+2 (air) then drop down?
        move.goTo(job.target.x - 1, job.target.y, job.target.z)
        move.turnTo(1) -- Face East (towards tree)
        
        -- 2. Chop & Replant
        chopTree()
        
        -- 3. Check Inventory
        if turtle.getItemCount(16) > 0 then
            dumpInventory(job.dropoff)
        end
        
    elseif job == "WAIT" then
        print("Queue empty. Sleeping 10s...")
        sleep(10)
    end
    
    sleep(1)
end