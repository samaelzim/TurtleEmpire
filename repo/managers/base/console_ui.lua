-- ============================================================================
-- FILE: console_ui.lua
-- Role: Three-Monitor Command Center
-- Version: 1.2.1
-- ============================================================================
local net = require("hive_net")
local UI_VERSION = "1.2.1"

local screens = {}
local log_buffer = {}
local slot_map = {}
local next_fleet_line = 3
local is_emergency = false

local function init_monitors()
    local mapping = { stats = "left", fleet = "top", log = "right" }
    for name, side in pairs(mapping) do
        local obj = peripheral.wrap(side)
        if obj then
            obj.setTextScale(0.5)
            local w, h = obj.getSize()
            screens[name] = { handle = obj, w = w, h = h }
        else
            error("Monitor missing: " .. side)
        end
    end
end

local function add_to_log(text, color)
    local scr = screens.log
    table.insert(log_buffer, {msg = text, col = color or colors.white})
    if #log_buffer > scr.h then table.remove(log_buffer, 1) end
    scr.handle.clear()
    for i, entry in ipairs(log_buffer) do
        scr.handle.setCursorPos(1, i)
        scr.handle.setTextColor(entry.col)
        scr.handle.write("> " .. entry.msg)
    end
end

local function update_fleet_row(data)
    local scr = screens.fleet
    if not slot_map[data.id] then
        slot_map[data.id] = next_fleet_line
        next_fleet_line = next_fleet_line + 1
    end
    local line = slot_map[data.id]
    scr.handle.setCursorPos(1, line)
    scr.handle.clearLine()
    scr.handle.setTextColor(data.is_local and colors.lightBlue or colors.white)
    scr.handle.write(string.format("%-10s %-8s ", data.id, data.dist_text))
    
    local bar_w = math.floor(scr.w * 0.4)
    local filled = math.floor((data.progress / 100) * (bar_w - 2))
    scr.handle.setTextColor(colors.green)
    scr.handle.write("[" .. string.rep("|", filled) .. string.rep(" ", (bar_w-2)-filled) .. "]")
    
    scr.handle.setTextColor(colors.gray)
    scr.handle.write(" " .. data.status)
end

local function network_listener()
    while true do
        local msg, sender = net.receive()
        if msg then
            -- Auto-ACK back to sender
            net.send(sender, "ACK", {received_type = msg.type})
            
            if msg.type == "UI_UPDATE" then
                update_fleet_row(msg.payload)
            elseif msg.type == "LOG_EVENT" then
                add_to_log(msg.payload.text, msg.payload.color)
            end
        end
    end
end

local function keyboard_input()
    while true do
        term.setCursorPos(1, 18)
        term.setTextColor(colors.yellow)
        term.write("CMD > ")
        local input = read()
        
        -- Split input into tokens for easier parsing
        local args = {}
        for word in input:gmatch("%S+") do table.insert(args, word) end
        local cmd = args[1] and args[1]:lower()

        -- 1. OTA UPDATE: update <id> <role>
        if cmd == "update" then
            local id, role = tonumber(args[2]), args[3]
            if id and role then
                add_to_log("FORCING OTA: ID " .. id, colors.purple)
                net.send("HIVE_ARCHIVE", "FORCE_OTA", { id = id, role = role:upper() })
            else
                add_to_log("USAGE: update <id> <role>", colors.gray)
            end

        -- 2. RESET: reset <id_or_name>
        elseif cmd == "reset" then
            local target = args[2]
            if target then
                add_to_log("SENDING RESET: " .. target, colors.yellow)
                if net.send_safe("HIVE_BRAIN", "FORCE_RESUME", {id = target}) then
                    add_to_log("RESET SUCCESS", colors.green)
                else
                    add_to_log("RESET FAILED", colors.red)
                end
            end

        -- 3. QUARRY: quarry [L] [W] [D] [X] [Y] [Z]
        elseif cmd == "quarry" then
            local payload = {
                mode   = "QUARRY",
                length = tonumber(args[2]) or 16,
                width  = tonumber(args[3]) or 16,
                depth  = tonumber(args[4]) or 20,
                x      = tonumber(args[5]), -- Optional: Target X
                y      = tonumber(args[6]), -- Optional: Target Y
                z      = tonumber(args[7])  -- Optional: Target Z
            }
            local loc_str = payload.x and (payload.x..","..payload.y..","..payload.z) or "HERE"
            add_to_log("QUEUING QUARRY at " .. loc_str, colors.cyan)
            if net.send_safe("MINER_MANAGER", "NEW_JOB_ENQUEUE", payload) then
                add_to_log("MANAGER: JOB QUEUED", colors.green)
            else
                add_to_log("MANAGER: OFFLINE", colors.red)
            end

        -- 4. BRANCH: branch [L] [BL] [X] [Y] [Z]
        elseif cmd == "branch" then
            local payload = {
                mode       = "BRANCH",
                length     = tonumber(args[2]) or 32,
                branch_len = tonumber(args[3]) or 16,
                x          = tonumber(args[4]),
                y          = tonumber(args[5]),
                z          = tonumber(args[6])
            }
            add_to_log("QUEUING BRANCH MINE", colors.cyan)
            if net.send_safe("MINER_MANAGER", "NEW_JOB_ENQUEUE", payload) then
                add_to_log("MANAGER: JOB QUEUED", colors.green)
            else
                add_to_log("MANAGER: OFFLINE", colors.red)
            end
        end
        
        -- Clean up terminal line
        term.setCursorPos(1, 18)
        term.clearLine()
    end
end

init_monitors()
rednet.host("HIVE_PROT_V1", "HIVE_CONSOLE")
parallel.waitForAny(network_listener, keyboard_input)