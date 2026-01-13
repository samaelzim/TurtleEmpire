-- ============================================================================
-- FILE: brain_core.lua
-- Role: Fleet Intelligence, GPS Anchor, and Registry Master
-- Version: 1.2.1
-- ============================================================================
package.path = package.path .. ";repo/lib/?.lua"
local net = require("hive_net")
local BRAIN_VERSION = "1.2.1"

-- 1. STATE & REGISTRY
local fleet = {}
local is_gps_locked = false
local base_pos = {x = 0, y = 0, z = 0}
local last_checkpoint = os.clock()

-- 2. GEOMETRY & FORMATTING
local function get_location_data(mx, mz)
    local dx = mx - base_pos.x
    local dz = mz - base_pos.z
    local dist = math.floor(math.sqrt(dx^2 + dz^2))
    
    local angle = math.deg(math.atan2(dz, dx))
    if angle < 0 then angle = angle + 360 end
    local directions = {"E", "SE", "S", "SW", "W", "NW", "N", "NE"}
    local dir_text = directions[math.floor((angle + 22.5) / 45) % 8 + 1]

    if dist < 10 then
        return "LOCAL", "", true
    end
    return dist .. "m", dir_text, false
end

-- 3. GPS WATCHDOG & LOCKDOWN
local function check_gps()
    local x, y, z = gps.locate(5)
    if not x then
        if not is_gps_locked then
            is_gps_locked = true
            net.send("HIVE_CONSOLE", "LOG_EVENT", {text = "CRITICAL: GPS ANCHOR LOST", color = colors.red})
            -- Signal fleet to standby (broadcast doesn't use ACKs)
            rednet.broadcast({type = "GPS_LOST_STANDBY", payload = {}}, "HIVE_PROT_V1")
        end
    else
        if is_gps_locked then
            is_gps_locked = false
            net.send("HIVE_CONSOLE", "LOG_EVENT", {text = "GPS Restored. Resuming...", color = colors.green})
            rednet.broadcast({type = "GPS_RESTORED", payload = {x=x, y=y, z=z}}, "HIVE_PROT_V1")
        end
        base_pos = {x=x, y=y, z=z}
    end
end

-- 4. REGISTRY HANDLER
local function handle_heartbeat(id, payload)
    if is_gps_locked then return end

    local manager = fleet[id] or { strikes = 0, status = "ONLINE" }
    local d_text, dir_text, is_local = get_location_data(payload.x, payload.z)
    
    fleet[id] = {
        id = id,
        status = manager.status,
        dist_text = d_text,
        dir_text = dir_text,
        is_local = is_local,
        progress = payload.progress or 0,
        bpm = payload.bpm or 0,
        last_seen = os.clock(),
        strikes = manager.strikes or 0
    }

    net.send("HIVE_CONSOLE", "UI_UPDATE", fleet[id])
end

-- 5. MAIN EXECUTION
term.clear()
term.setCursorPos(1,1)
print("HIVE_BRAIN v" .. BRAIN_VERSION)

if not net.init() then error("Network Init Failed!") end
rednet.host("HIVE_PROT_V1", "HIVE_BRAIN") 

while true do
    local msg, sender = net.receive(nil, 1) 
    
    if msg then
        -- Bulletproof ACK Responder
        net.send(sender, "ACK", { received_type = msg.type })

        if msg.type == "HEARTBEAT" then
            handle_heartbeat(sender, msg.payload)
        elseif msg.type == "FORCE_RESUME" then
            if fleet[msg.payload.id] then
                fleet[msg.payload.id].status = "ONLINE"
                fleet[msg.payload.id].strikes = 0
                net.send("HIVE_CONSOLE", "LOG_EVENT", {text = "Override: " .. msg.payload.id, color = colors.yellow})
            end
        end
    end

    check_gps()
    
    if os.clock() - last_checkpoint > 300 then
        local f = fs.open("fleet_state.json", "w")
        f.write(textutils.serializeJSON(fleet))
        f.close()
        last_checkpoint = os.clock()
    end
end