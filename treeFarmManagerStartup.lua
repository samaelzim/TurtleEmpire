-- ============================================================================
-- FILE: treeFarmManagerStartup.lua
-- VERSION: 1.0.0
-- ============================================================================
local VERSION = "1.0.0"

rednet.open("top") -- Ensure this matches your modem side
local PROTOCOL = "LUMBER_V1"

-- CONFIGURATION (Relative to this computer)
-- 0=North, 1=East, 2=South, 3=West
local FARM_OFFSET_DIR = 0 
local FARM_START_DIST = 2 
local ROWS = 3       -- How many rows of trees
local COLS = 4       -- How many trees per row
local SPACING = 2    -- Blocks between trees

-- UI SETUP
term.clear()
term.setCursorPos(1,1)
print("TREE FARM MANAGER v" .. VERSION)
print("---------------------------")

-- 1. GET MY POSITION
print("Acquiring GPS Signal...")
local myX, myY, myZ = gps.locate(5)
if not myX then
    error("GPS FAILURE: Could not locate Manager Computer!")
end
print(string.format("Host Pos: %d, %d, %d", myX, myY, myZ))

-- 2. GENERATE TREE COORDINATES
local treeList = {}
local count = 0

for r = 0, ROWS - 1 do
    for c = 0, COLS - 1 do
        count = count + 1
        
        -- Simple Grid Logic (Grows East +X and South +Z currently)
        -- You may need to adjust the (+/-) logic if your farm faces a different way
        local treeX = myX + (c * SPACING) 
        local treeZ = myZ - (FARM_START_DIST) - (r * SPACING) 
        
        table.insert(treeList, {
            id = count,
            target = {x=treeX, y=myY, z=treeZ} 
        })
    end
end

-- DROPOFF CHEST (Assume it is 1 block ABOVE this computer)
local DROPOFF = {x=myX, y=myY + 1, z=myZ}

print(string.format("Zone Generated: %d Trees", #treeList))

-- 3. JOB QUEUE SYSTEM
local jobQueue = {}
-- Fill queue initially
for _, tree in ipairs(treeList) do
    table.insert(jobQueue, tree)
end

print("Waiting for workers...")

while true do
    local senderId, msg = rednet.receive(PROTOCOL)
    
    if msg == "REQUEST_JOB" or (type(msg) == "table" and msg.type == "REQUEST_JOB") then
        if #jobQueue > 0 then
            -- Pop first job
            local job = table.remove(jobQueue, 1) 
            
            local packet = {
                type = "CHOP",
                id = job.id,
                target = job.target,
                dropoff = DROPOFF,
                managerVersion = VERSION
            }
            
            print("Assigning Tree #"..job.id.." -> Turtle #"..senderId)
            rednet.send(senderId, packet, PROTOCOL)
            
            -- Round Robin: Add to back of queue immediately
            -- (In a more advanced version, we would wait for 'JOB_COMPLETE')
            table.insert(jobQueue, job)
        else
            rednet.send(senderId, "WAIT", PROTOCOL)
        end
    end
end