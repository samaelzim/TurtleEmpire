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
        if input:sub(1,5) == "reset" then
            local target = input:sub(7)
            add_to_log("SENDING RESET: " .. target, colors.yellow)
            if net.send_safe("HIVE_BRAIN", "FORCE_RESUME", {id = target}) then
                add_to_log("RESET SUCCESS", colors.green)
            else
                add_to_log("RESET FAILED (NO ACK)", colors.red)
            end
        end
        term.setCursorPos(1, 18)
        term.clearLine()
    end
end

init_monitors()
rednet.host("HIVE_PROT_V1", "HIVE_CONSOLE")
parallel.waitForAny(network_listener, keyboard_input)