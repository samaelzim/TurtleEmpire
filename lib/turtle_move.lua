-- ============================================================================
-- FILE: lib/turtle_move.lua (Shared Movement Library)
-- ============================================================================
local move = {}

-- STATE TRACKING
move.x, move.y, move.z = 0, 0, 0
move.facing = 0 -- 0=North(-Z), 1=East(+X), 2=South(+Z), 3=West(-X)
move.hasCalibrated = false

-- CONFIG
local MIN_FUEL = 200

-- ============================================================================
-- 1. UTILITIES
-- ============================================================================
function move.refuel()
    if turtle.getFuelLevel() < MIN_FUEL then
        print("[MOVE] Low Fuel. Attempting refuel...")
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then -- Check if item is fuel
                turtle.refuel(1) -- Consume 1
                if turtle.getFuelLevel() >= MIN_FUEL then break end
            end
        end
        if turtle.getFuelLevel() < MIN_FUEL then
            error("CRITICAL: OUT OF FUEL")
        end
    end
end

-- Determine position and facing using GPS
function move.calibrate()
    print("[MOVE] Calibrating GPS...")
    local x1, y1, z1 = gps.locate(2)
    if not x1 then error("No GPS Signal!") end

    -- We must move to determine facing
    if not turtle.forward() then
        if not turtle.dig() then error("Calibration blocked!") end
        turtle.forward()
    end

    local x2, y2, z2 = gps.locate(2)
    
    -- Calculate Facing
    if z2 < z1 then move.facing = 0       -- North
    elseif x2 > x1 then move.facing = 1   -- East
    elseif z2 > z1 then move.facing = 2   -- South
    elseif x2 < x1 then move.facing = 3   -- West
    end

    move.x, move.y, move.z = x2, y2, z2
    move.hasCalibrated = true
    print(string.format("[MOVE] Loc: %d,%d,%d | Facing: %d", x2, y2, z2, move.facing))
    
    -- Move back to start
    turtle.back()
    move.updatePos("back")
end

function move.updatePos(action)
    if action == "forward" then
        if move.facing == 0 then move.z = move.z - 1
        elseif move.facing == 1 then move.x = move.x + 1
        elseif move.facing == 2 then move.z = move.z + 1
        elseif move.facing == 3 then move.x = move.x - 1
        end
    elseif action == "back" then
        if move.facing == 0 then move.z = move.z + 1
        elseif move.facing == 1 then move.x = move.x - 1
        elseif move.facing == 2 then move.z = move.z - 1
        elseif move.facing == 3 then move.x = move.x + 1
        end
    elseif action == "up" then move.y = move.y + 1
    elseif action == "down" then move.y = move.y - 1
    end
end

-- ============================================================================
-- 2. CORE MOVEMENT (Dig > Move)
-- ============================================================================
function move.forward()
    move.refuel()
    while not turtle.forward() do
        -- If blocked, dig or attack
        if turtle.detect() then
            turtle.dig()
        elseif turtle.attack() then
            -- Mobs killed
        else
            sleep(0.5) -- Bedrock or other player?
        end
    end
    move.updatePos("forward")
end

function move.up()
    move.refuel()
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp()
        else turtle.attackUp() end
    end
    move.updatePos("up")
end

function move.down()
    move.refuel()
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown()
        else turtle.attackDown() end
    end
    move.updatePos("down")
end

-- Smart Turning
function move.turnTo(targetFacing)
    local diff = (targetFacing - move.facing) % 4
    if diff == 1 then
        turtle.turnRight()
    elseif diff == 2 then
        turtle.turnRight()
        turtle.turnRight()
    elseif diff == 3 then
        turtle.turnLeft()
    end
    move.facing = targetFacing
end

-- ============================================================================
-- 3. PATHFINDING (Go To Coordinate)
-- ============================================================================
function move.goTo(tx, ty, tz)
    if not move.hasCalibrated then move.calibrate() end

    -- 1. Match Y (Height) first to avoid crashing into trees/buildings
    -- Usually safer to go UP first, then over, then down
    if move.y < ty then
        while move.y < ty do move.up() end
    elseif move.y > ty then
        -- We delay going down until we are over the target
    end

    -- 2. Match X
    if move.x < tx then
        move.turnTo(1) -- East
        while move.x < tx do move.forward() end
    elseif move.x > tx then
        move.turnTo(3) -- West
        while move.x > tx do move.forward() end
    end

    -- 3. Match Z
    if move.z < tz then
        move.turnTo(2) -- South
        while move.z < tz do move.forward() end
    elseif move.z > tz then
        move.turnTo(0) -- North
        while move.z > tz do move.forward() end
    end

    -- 4. Match Y (Down)
    if move.y > ty then
        while move.y > ty do move.down() end
    end
end

return move