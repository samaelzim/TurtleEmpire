-- ============================================================================
-- ROLE: MINER (Mixed Mode: Efficient Quarry + Safe Branch)
-- VERSION: 1.2.1 (Bulletproof Protocol)
-- ============================================================================

-- 1. DEPENDENCIES
package.path = package.path .. ";repo/lib/?.lua"
local move = require("turtle_move") 
local net  = require("hive_net")    

-- 2. CONFIGURATION
local VERSION       = "1.2.1"
local PROTOCOL      = "HIVE_PROT_V1"
local MIN_FUEL      = 1000  
local HOME_POS      = nil   
local IDLE_SLEEP    = 5     
local MANAGER_NAME  = "MINER_MANAGER"

-- ============================================================================
-- 3. EMERGENCY & NETWORK HELPERS
-- ============================================================================

-- Checks for GPS Lockdown broadcasts from the HIVE_BRAIN
local function check_emergency()
    local msg, sender = net.receive(nil, 0) -- Non-blocking check
    if msg then
        -- Acknowledge the message if it's directed at us
        net.send(sender, "ACK", { received_type = msg.type })

        if msg.type == "GPS_LOST_STANDBY" then
            print("[CRITICAL] GPS LOCKDOWN. SUSPENDING...")
            -- Loop until GPS is restored
            while true do
                local e_msg = net.receive("GPS_RESTORED")
                if e_msg then 
                    print("[SYSTEM] GPS Restored. Resuming...")
                    break 
                end
                sleep(5)
            end
        elseif msg.type == "COMMAND" and msg.payload.cmd == "ABORT" then
            error("JOB_ABORTED")
        end
    end
end

local function secure_drop()
    while not turtle.drop() do
        print("[CRITICAL] Chest Full. Creating Ticket...")
        
        -- Use send_safe to ensure the Manager logs the issue
        local success = net.send_safe(MANAGER_NAME, "TICKET_CREATE", {
            priority = "CRITICAL",
            type = "LOGISTICS",
            msg = "CHEST_FULL",
            id = os.getComputerID(),
            coords = {x=move.x, y=move.y, z=move.z}
        })
        
        if success then
            print(">> Ticket Logged. Waiting for empty chest...")
            while not turtle.drop() do sleep(10) end
        else
            print(">> Manager unreachable. Retrying ticket...")
            sleep(5)
        end
    end
end

local function maintenance_stop()
    print("[OP] Performing Maintenance...")
    move.turnTo((move.facing + 2) % 4)
    while turtle.getFuelLevel() < MIN_FUEL do
        local found = false
        turtle.select(1)
        if turtle.refuel(0) then turtle.refuel(1) found = true
        else
            for i = 2, 16 do
                turtle.select(i)
                if turtle.refuel(0) then turtle.transferTo(1) found = true break end
            end
        end
        if not found then break end
    end
    for i = 2, 16 do
        turtle.select(i)
        if turtle.getItemCount(i) > 0 then secure_drop() end
    end
    turtle.select(1)
    move.turnTo((move.facing + 2) % 4)
end

-- ============================================================================
-- 4. BRANCH MINING (Safe Mode)
-- ============================================================================

local function dig_branch_line(len)
    for i = 1, len do
        check_emergency() -- Prevent moving during GPS failure
        move.forward() 
        while turtle.detectDown() do 
            check_emergency()
            turtle.digDown() 
        end
        
        if turtle.getItemCount(16) > 0 then
            print("[OP] Full. Returning...")
            move.saveState()
            local rx, ry, rz, rf = move.x, move.y, move.z, move.facing
            move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
            maintenance_stop()
            move.goTo(rx, ry, rz)
            move.turnTo(rf)
        end
    end
end

local function run_branch_mine(params)
    print("STARTING FISHBONE: Len="..params.length)
    local main_len = params.length
    local side_len = params.branch_len
    
    for dist = 1, main_len do
        dig_branch_line(1)
        local cycle = dist % 4
        if cycle == 0 then
            move.turnTo((move.facing - 1) % 4)
            dig_branch_line(side_len)
            move.turnTo((move.facing + 2) % 4)
            move.forward(side_len)
            move.turnTo((move.facing + 1) % 4)
        elseif cycle == 2 then
            move.turnTo((move.facing + 1) % 4)
            dig_branch_line(side_len)
            move.turnTo((move.facing + 2) % 4)
            move.forward(side_len)
            move.turnTo((move.facing - 1) % 4)
        end
    end
    move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
    maintenance_stop()
    if fs.exists(".pos") then fs.delete(".pos") end
    if fs.exists(".facing") then fs.delete(".facing") end
end

-- ============================================================================
-- 5. QUARRY LOGIC (Efficient Mode)
-- ============================================================================

local function dig_3_stack()
    check_emergency()
    while turtle.detectUp() do turtle.digUp() end
    while turtle.detectDown() do turtle.digDown() end
end

local function dig_quarry_row(length)
    for i = 1, length - 1 do
        dig_3_stack()
        move.forward()
        if turtle.getItemCount(16) > 0 then
            move.saveState()
            local rx, ry, rz, rf = move.x, move.y, move.z, move.facing
            move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
            maintenance_stop() 
            move.goTo(rx, ry, rz)
            move.turnTo(rf)
        end
    end
    dig_3_stack()
end

local function run_quarry(params)
    local width, length, depth = params.width or 16, params.length or 16, params.depth or 60
    local layers_needed = math.ceil(depth / 3)
    for layer = 1, layers_needed do
        for row = 1, width do
            dig_quarry_row(length)
            if row < width then
                local dir = (row % 2 == 1) and 1 or -1
                move.turnTo((move.facing + dir) % 4)
                dig_3_stack()
                move.forward() 
                move.turnTo((move.facing + dir) % 4)
            end
        end
        if layer < layers_needed then
            for d = 1, 3 do move.down() end
            move.turnTo((move.facing + 2) % 4)
        end
    end
    move.goTo(HOME_POS.x, HOME_POS.y, HOME_POS.z)
    maintenance_stop()
    if fs.exists(".pos") then fs.delete(".pos") end
    if fs.exists(".facing") then fs.delete(".facing") end
end

-- ============================================================================
-- 6. MAIN LOOP
-- ============================================================================

term.clear()
print("MINER OS v" .. VERSION)
print("Protocol: " .. PROTOCOL)

if not net.init() then error("Modem missing!") end
move.init() 

local hx, hy, hz = gps.locate(5)
if not hx then error("Initial GPS fix failed!") end
HOME_POS = vector.new(hx, hy, hz)

print("Home Set: " .. hx .. ", " .. hz)

while true do
    print("Requesting Job from " .. MANAGER_NAME .. "...")
    
    -- Request job with fuel status
    net.send(MANAGER_NAME, "JOB_REQUEST", { fuel = turtle.getFuelLevel() })
    
    -- Wait for assignment
    local msg, sender = net.receive("JOB_ASSIGN", IDLE_SLEEP)
    
    if msg then
        -- ACK back to Manager
        net.send(sender, "ACK", { received_type = "JOB_ASSIGN" })
        
        local success, err = pcall(function()
            if msg.payload.mode == "BRANCH" then 
                run_branch_mine(msg.payload)
            elseif msg.payload.mode == "QUARRY" then 
                run_quarry(msg.payload) 
            end
        end)
        
        if not success then 
            print("JOB ERR: " .. tostring(err))
            sleep(5)
        end
    else
        print("No job available. Sleeping...")
        check_emergency() -- Check for alerts during idle
        sleep(2)
    end
end