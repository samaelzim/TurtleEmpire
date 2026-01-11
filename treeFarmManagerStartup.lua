-- ============================================================================
-- FILE: treeFarmManagerStartup.lua (DYNAMIC GPS VERSION)
-- ============================================================================
rednet.open("top")
local PROTOCOL = "LUMBER_V1"

-- CONFIGURATION (Relative to this computer)
-- 0=North, 1=East, 2=South, 3=West
-- Example: Trees start 2 blocks NORTH of this computer
local FARM_OFFSET_DIR = 0 
local FARM_START_DIST = 2 

local ROWS = 3       -- How many rows of trees
local COLS = 4       -- How many trees per row
local SPACING = 2    -- Blocks between trees (1 means adjacent, 2 means 1 block gap)

-- 1. GET MY POSITION
print("Acquiring GPS Signal...")
local myX, myY, myZ = gps.locate(5)
if not myX then
    error("GPS FAILURE: Could not locate Manager Computer!")
end
print(string.format("Manager Location: %d, %d, %d", myX, myY, myZ))

-- 2. GENERATE TREE COORDINATES
local treeList = {}
local count = 0

-- Vector Math helper to calculate relative positions
-- (Simplifying: Assuming farm grows in +X and +Z directions for now)
-- You might want to tweak this based on which way your farm faces
for r = 0, ROWS - 1 do
    for c = 0, COLS - 1 do
        count = count + 1
        
        -- Simple Grid Logic (Adjust multipliers to rotate farm)
        -- Currently grows East (+X) and South (+Z)
        local treeX = myX + (c * SPACING) 
        local treeZ = myZ - (FARM_START_DIST) - (r * SPACING) 
        
        table.insert(treeList, {
            id = count,
            target = {x=treeX, y=myY, z=treeZ} -- Trees act as if on same Y level
        })
    end
end

-- DROPOFF CHEST (Assume it is 1 block ABOVE this computer)
local DROPOFF = {x=myX, y=myY + 1, z=myZ}

print(string.format("Farm Generated: %d Trees", #treeList))

-- 3. JOB QUEUE SYSTEM
local jobQueue = {}
-- Fill queue initially
for _, tree in ipairs(treeList) do
    table.insert(jobQueue, tree)
end

print("Waiting for workers...")

while true do
    local senderId, msg = rednet.receive(PROTOCOL)
    
    if msg == "REQUEST_JOB" then
        if #jobQueue > 0 then
            local job = table.remove(jobQueue, 1) -- Get next tree
            
            local packet = {
                type = "CHOP",
                id = job.id,
                target = job.target,
                dropoff = DROPOFF
            }
            
            print("Sending Turtle #"..senderId.." to Tree #"..job.id)
            rednet.send(senderId, packet, PROTOCOL)
            
            -- Round Robin: Add to back of queue immediately
            -- (Real version would wait for 'JOB_COMPLETE' message)
            table.insert(jobQueue, job)
        else
            rednet.send(senderId, "WAIT", PROTOCOL)
        end
    end
end