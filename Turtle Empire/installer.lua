-- ============================================================================
-- FILE: installer.lua (FIXED BRANCH)
-- ============================================================================

local BASE_URL = "https://raw.githubusercontent.com/samaelzim/TurtleEmpire/main/Turtle%20Empire/"

local FILES = {
    ["baseStartup.lua"]     = "startup.lua",
    ["connection_test.lua"] = "connection_test.lua"
}

print("Connecting to Turtle Empire Repo...")
print("-------------------------------")

for remoteName, localName in pairs(FILES) do
    local url = BASE_URL .. remoteName
    print("Fetching: " .. remoteName)
    
    local response = http.get(url)

    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(localName, "w")
        file.write(content)
        file.close()
        print(" [OK] Saved " .. localName)
    else
        print(" [ERR] Failed.")
        print(" URL: " .. url)
    end
end

print("\nUpdate Complete. Rebooting in 3...")
sleep(3)
os.reboot()