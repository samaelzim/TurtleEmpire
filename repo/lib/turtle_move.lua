-- ============================================================================
-- FILE: lib/turtle_move.lua
-- VERSION: 1.1.0 (Persistence Enabled)
-- ============================================================================
local move = {}
move.VERSION = "1.1.0"

move.x, move.y, move.z = 0, 0, 0
move.facing = 0 -- 0=N, 1=E, 2=S, 3=W
move.hasCalibrated = false
local POS_FILE = ".pos"

function move.saveState()
    local f = fs.open(POS_FILE, "w")
    f.write(textutils.serialize({
        x = move.x, y = move.y, z = move.z,
        facing = move.facing, calibrated = move.hasCalibrated
    }))
    f.close()
end

function move.loadState()
    if fs.exists(POS_FILE) then
        local f = fs.open(POS_FILE, "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        if data then
            move.x, move.y, move.z = data.x, data.y, data.z
            move.facing = data.facing
            move.hasCalibrated = data.calibrated
            return true
        end
    end
    return false
end

function move.refuel()
    if turtle.getFuelLevel() < 200 then
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(0) then
                turtle.refuel(1)
                if turtle.getFuelLevel() >= 200 then break end
            end
        end
    end
end

function move.calibrate()
    print("[MOVE] GPS Calibration...")
    local x1, y1, z1 = gps.locate(2)
    if not x1 then error("No GPS Signal!") end
    if not turtle.forward() then turtle.dig() turtle.forward() end
    local x2, y2, z2 = gps.locate(2)
    if z2 < z1 then move.facing = 0
    elseif x2 > x1 then move.facing = 1
    elseif z2 > z1 then move.facing = 2
    elseif x2 < x1 then move.facing = 3 end
    move.x, move.y, move.z = x2, y2, z2
    move.hasCalibrated = true
    move.saveState()
end

function move.init()
    if not move.loadState() then move.calibrate() end
end

function move.updatePos(action)
    if action == "forward" then
        if move.facing == 0 then move.z = move.z - 1
        elseif move.facing == 1 then move.x = move.x + 1
        elseif move.facing == 2 then move.z = move.z + 1
        elseif move.facing == 3 then move.x = move.x - 1 end
    elseif action == "back" then
        if move.facing == 0 then move.z = move.z + 1
        elseif move.facing == 1 then move.x = move.x - 1
        elseif move.facing == 2 then move.z = move.z - 1
        elseif move.facing == 3 then move.x = move.x + 1 end
    elseif action == "up" then move.y = move.y + 1
    elseif action == "down" then move.y = move.y - 1 end
    move.saveState()
end

function move.forward()
    move.refuel()
    while not turtle.forward() do
        if turtle.detect() then turtle.dig()
        elseif not turtle.attack() then sleep(0.5) end
    end
    move.updatePos("forward")
end

function move.up()
    move.refuel()
    while not turtle.up() do
        if turtle.detectUp() then turtle.digUp() else sleep(0.5) end
    end
    move.updatePos("up")
end

function move.down()
    move.refuel()
    while not turtle.down() do
        if turtle.detectDown() then turtle.digDown() else sleep(0.5) end
    end
    move.updatePos("down")
end

function move.turnTo(target)
    local diff = (target - move.facing) % 4
    if diff == 1 then turtle.turnRight()
    elseif diff == 2 then turtle.turnRight() turtle.turnRight()
    elseif diff == 3 then turtle.turnLeft() end
    move.facing = target
    move.saveState()
end

function move.goTo(tx, ty, tz)
    if move.y < ty then while move.y < ty do move.up() end end
    if move.x < tx then move.turnTo(1) while move.x < tx do move.forward() end
    elseif move.x > tx then move.turnTo(3) while move.x > tx do move.forward() end end
    if move.z < tz then move.turnTo(2) while move.z < tz do move.forward() end
    elseif move.z > tz then move.turnTo(0) while move.z > tz do move.forward() end end
    if move.y > ty then while move.y > ty do move.down() end end
end

return move