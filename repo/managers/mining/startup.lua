-- ============================================================================
-- MANAGER: MINING
-- VERSION: 1.2.1
-- Location: repo/managers/mining/startup.lua
-- Role: Field Commander for Mining Fleet
-- ============================================================================

package.path = package.path .. ";repo/lib/?.lua"
local net = require("hive_net")

-- CONFIGURATION
local PROTOCOL_VERSION = "1.2.1"
local PATH_QUEUE  = "mining_queue.json"
local PATH_ACTIVE = "mining_active.json"
local HEARTBEAT_INTERVAL = 5
local last_heartbeat = 0

-- STATE DATA
local job_queue = {}    -- List of jobs waiting
local active_jobs = {}  -- Map of { [turtleID] = jobData }
local is_emergency_paused = false

-- ============================================================================
-- 1. PERSISTENCE (Bulletproof Saving/Loading)
-- ============================================================================

local function save_state()
    local f_queue = fs.open(PATH_QUEUE, "w")
    f_queue.write(textutils.serializeJSON(job_queue))
    f_queue.close()

    local f_active = fs.open(PATH_ACTIVE, "w")
    f_active.write(textutils.serializeJSON(active_jobs))
    f_active.close()
end

local function load_state()
    if fs.exists(PATH_QUEUE) then
        local f = fs.open(PATH_QUEUE, "r")
        job_queue = textutils.unserializeJSON(f.readAll()) or {}
        f.close()
    end
    if fs.exists(PATH_ACTIVE) then
        local f = fs.open(PATH_ACTIVE, "r")
        active_jobs = textutils.unserializeJSON(f.readAll()) or {}
        f.close()
    end
end

-- ============================================================================
-- 2. MESSAGE HANDLERS
-- ============================================================================

-- A. Handle New Job from Base Station
local function handle_base_dispatch(payload)
    table.insert(job_queue, payload)
    save_state()
    print("[BASE] Job Enqueued: " .. payload.mode)
    return true
end

-- B. Handle Job Request from Turtle
local function handle_turtle_request(turtle_id)
    if active_jobs[tostring(turtle_id)] then
        print("[TURTLE] ID " .. turtle_id .. " reconnected. Resending active job.")
        net.send(turtle_id, "JOB_ASSIGN", active_jobs[tostring(turtle_id)])
        return
    end

    if #job_queue > 0 then
        local new_job = table.remove(job_queue, 1)
        active_jobs[tostring(turtle_id)] = new_job
        save_state()
        
        print("[TURTLE] ID " .. turtle_id .. " assigned to " .. new_job.mode)
        net.send(turtle_id, "JOB_ASSIGN", new_job)
    else
        print("[TURTLE] ID " .. turtle_id .. " requested job, but queue is empty.")
    end
end

-- ============================================================================
-- 3. MAIN LOOP
-- ============================================================================

term.clear()
term.setCursorPos(1,1)
print("MINING MANAGER (v" .. PROTOCOL_VERSION .. ")")
print("-----------------------------------")

if not net.init() then 
    error("Modem check failed!") 
end

-- Identify as MINER_MANAGER so HIVE_BRAIN can track it
rednet.host("HIVE_PROT_V1", "MINER_MANAGER")

load_state()
local active_count = 0
for _ in pairs(active_jobs) do active_count = active_count + 1 end
print("State Loaded. Queue: " .. #job_queue .. " | Active: " .. active_count)

while true do
    -- We listen for messages from Base, Turtles, and Broadcasts
    local msg, sender_id = net.receive(nil, 0.5) 
    
    if msg then
        -- BULLETPROOF ACK: Immediately acknowledge any non-ACK message
        if msg.type ~= "ACK" then
            net.send(sender_id, "ACK", { received_type = msg.type })
        end

        -- CASE 1: Dispatch from Archive or Brain
        if msg.type == "NEW_JOB_ENQUEUE" then
            if handle_base_dispatch(msg.payload) then
                net.send("HIVE_CONSOLE", "LOG_EVENT", { text = "Job Received: " .. msg.payload.mode, color = colors.green })
            end

        -- CASE 2: Request from Turtle
        elseif msg.type == "JOB_REQUEST" then
            handle_turtle_request(sender_id)

        -- CASE 3: Ticket/Emergency from Turtle
        elseif msg.type == "TICKET_CREATE" then
            print("[TICKET] " .. msg.payload.msg .. " from ID " .. sender_id)
            net.send("HIVE_CONSOLE", "LOG_EVENT", { text = "TICKET [" .. sender_id .. "]: " .. msg.payload.msg, color = colors.red })

        -- CASE 4: GPS Lockdown Signals (Broadcasts)
        elseif msg.type == "GPS_LOST_STANDBY" then
            is_emergency_paused = true
            print("!! EMERGENCY STANDBY: GPS LOST")
        elseif msg.type == "GPS_RESTORED" then
            is_emergency_paused = false
            print(">> GPS RESTORED: RESUMING")
        end
    end

    -- HEARTBEAT LOGIC: Send data to HIVE_BRAIN for the Console UI
    if os.clock() - last_heartbeat > HEARTBEAT_INTERVAL then
        local x, y, z = gps.locate(2)
        if x then
            local current_status = is_emergency_paused and "STANDBY" or "ONLINE"
            if #job_queue == 0 and active_count == 0 then current_status = "IDLE" end
            
            -- Calculate progress based on active jobs vs queue (simple example)
            local progress_pct = 0
            if active_count > 0 then progress_pct = 50 end -- Logic for real progress goes here

            net.send("HIVE_BRAIN", "HEARTBEAT", {
                x = x,
                y = y,
                z = z,
                status = current_status,
                progress = progress_pct,
                bpm = active_count * 5 -- Arbitrary efficiency metric
            })
        end
        last_heartbeat = os.clock()
    end
end