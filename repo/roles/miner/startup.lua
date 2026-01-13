-- ============================================================================
-- ROLE: MINER (Full Operation + OTA + Calibration + XYZ)
-- VERSION: 1.5.2
-- ============================================================================
package.path = package.path .. ";repo/lib/?.lua"
local move = require("turtle_move") 
local net  = require("hive_net")    

local MANAGER_NAME = "MINER_MANAGER"
local ARCHIVE_NAME = "HIVE_ARCHIVE"
local HOME_POS = {x=0, y=0, z=0, f=0}

-- 1. UTILITY: Inventory Management
local function dump_inventory()
    print("Emptying Inventory...")
    for i = 1, 16 do
        local detail = turtle.getItemDetail(i)
        if detail and detail.name ~= "minecraft:coal" and detail.name ~= "minecraft:charcoal" then
            turtle.select(i)
            turtle.dropDown()
        end
    end
    turtle.select(1)
end

local function check_fuel()
    if turtle.getFuelLevel() < 200 then
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then turtle.refuel(8) end
        end
    end
    return turtle.getFuelLevel()
end

-- 2. CALIBRATION: Auto-Heading via GPS
local function calibrate()
    print("Calibrating Heading...")
    local x1, y1, z1 = gps.locate(5)
    if not x1 then error("GPS Required for Calibration") end
    
    local success = false
    for i = 1, 4 do
        if not turtle.detect() and turtle.forward() then
            local x2, y2, z2 = gps.locate(5)
            turtle.back()
            if x2 > x1 then move.facing = 0 -- East
            elseif x2 < x1 then move.facing = 2 -- West
            elseif z2 > z1 then move.facing = 1 -- South
            elseif z2 < z1 then move.facing = 3 -- North
            end
            success = true
            break
        end
        turtle.turnRight()
    end
    if not success then error("Calibration failed: Turtle is boxed in") end
    HOME_POS.x, HOME_POS.y, HOME_POS.z, HOME_POS.f = x1, y1, z1, move.facing
    print("Heading Fixed: " .. move.facing)
end

-- 3. MINING: Quarry Logic (The "Snake" Pattern)
local function run_quarry(l, w, d)
    print("Starting Quarry: " .. l .. "x" .. w .. "x" .. d)
    for depth = 1, d do
        for col = 1, w do
            for row = 1, l - 1 do
                while turtle.detect() do turtle.dig() sleep(0.4) end
                move.forward()
            end
            if col < w then
                if col % 2 == 1 then
                    turtle.turnRight()
                    while turtle.detect() do turtle.dig() end
                    move.forward()
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                    while turtle.detect() do turtle.dig() end
                    move.forward()
                    turtle.turnLeft()
                end
            end
        end
        -- Move down to next layer
        if depth < d then
            turtle.digDown()
            move.down()
            -- Flip orientation to snake back the other way
            turtle.turnRight()
            turtle.turnRight()
        end
        check_fuel()
    end
    print("Quarry Complete. Returning Home...")
    move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
end

-- 4. BRANCH MINING: (The Strip Mine Pattern)
local function run_branch(len, branch_len)
    print("Starting Branch Mine...")
    for i = 1, len, 3 do
        -- Main Shaft
        for j = 1, 3 do 
            while turtle.detect() do turtle.dig() end
            move.forward() 
        end
        -- Left Branch
        turtle.turnLeft()
        for b = 1, branch_len do 
            while turtle.detect() do turtle.dig() end
            move.forward() 
        end
        for b = 1, branch_len do move.back() end
        -- Right Branch
        turtle.turnRight() -- back to center
        turtle.turnRight() -- to the right
        for b = 1, branch_len do 
            while turtle.detect() do turtle.dig() end
            move.forward() 
        end
        for b = 1, branch_len do move.back() end
        turtle.turnLeft() -- back to center
    end
    move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
end

-- 5. OTA & NETWORK
local function check_updates()
    print("Checking OTA...")
    net.send(ARCHIVE_NAME, "CHECK_UPDATE", {role="MINER_TURTLE", id=os.getComputerID()})
    local msg = net.receive("OTA_UPDATE", 2)
    if msg then
        local f = fs.open(msg.payload.name, "w")
        f.write(msg.payload.content)
        f.close()
        if msg.payload.name == "startup.lua" then os.reboot() end
    end
end

-- 6. MAIN EXECUTION
net.init()
move.init()
calibrate()
check_updates()

while true do
    print("Waiting for Job...")
    net.send(MANAGER_NAME, "JOB_REQUEST", {fuel=turtle.getFuelLevel(), status="IDLE"})
    local msg = net.receive("JOB_ASSIGN", 15)
    
    if msg then
        local p = msg.payload
        if p.x and p.y and p.z then move.goTo(p.x, p.y, p.z) end
        
        if p.mode == "QUARRY" then
            run_quarry(p.length or 16, p.width or 16, p.depth or 20)
        elseif p.mode == "BRANCH" then
            run_branch(p.length or 32, p.branch_len or 16)
        end
        
        dump_inventory()
        check_updates()
    end
    sleep(5)
end