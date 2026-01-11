-- installer.lua

-- configuration 
local REPO_USER = "samaelzim"
local REPO_NAME = "TurleEmpire"
local BRANCH = "main"

-- Map: filename on github -> filename on computer
local FILES = {
    ["baseStartup.lua"] = "startup.lua",
    ["connection.lua"] = "connection.lua"
}

-- utility: download a single file from github
local function download(remoteFile, localFile)
    local url = string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", REPO_USER, REPO_NAME, BRANCH, remoteFile)
    print("Downloading " .. remoteFile .. "...")
    
    if reponse then
        local content = response.readAll()
        response.close()

        local file = fs.open(localFile, "w")
        file.write(content)
        file.close()
        print("Saved to " .. localFile)
    else
        print("Failed to download " .. remoteFile)
    end
end

-- main installation loop
print("Starting Turtle Empire Installer...")

for remoteFile, localFile in pairs(FILES) do
    download(remoteFile, localFile)
end 

print("Installation complete. Rebooting in 3 seconds...")
sleep(3)
os.reboot()