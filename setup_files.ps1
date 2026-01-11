# List of all the files you need
$files = @(
    "baseStartup.lua",
    "minerStartup.lua",
    "lumberjackStartup.lua",
    "arboristStartup.lua",
    "farmerStartup.lua",
    "courierStartup.lua",
    "treeFarmManagerStartup.lua",
    "quarryManagerStartup.lua",
    "farmManagerStartup.lua",
    "courierManagerStartup.lua"
)

# Loop through and create them
foreach ($filename in $files) {
    if (-not (Test-Path $filename)) {
        # Create the file with a simple print line inside
        New-Item -Path $filename -ItemType File -Value "print('System Boot: $filename')" | Out-Null
        Write-Host " [CREATED] $filename" -ForegroundColor Green
    } else {
        Write-Host " [EXISTS]  $filename (Skipped)" -ForegroundColor Yellow
    }
}

Write-Host "`nAll files checked. You can now delete this script if you want."