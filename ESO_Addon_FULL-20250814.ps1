# Paths
$DownloadFolder = Join-Path $env:USERPROFILE "Downloads\ESO-MM"

# Dynamically get the current Documents folder path (handles OneDrive redirect)
$DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$AddonFolder = Join-Path $DocumentsPath "Elder Scrolls Online\live\AddOns"

Write-Host "`n[INFO] Download folder: $DownloadFolder"
Write-Host "[INFO] AddOn folder:    $AddonFolder`n"

# Create folders if missing
if (-not (Test-Path $DownloadFolder)) { New-Item -Path $DownloadFolder -ItemType Directory | Out-Null }
if (-not (Test-Path $AddonFolder)) { New-Item -Path $AddonFolder -ItemType Directory | Out-Null }

# Global warning list
$Global:WarningMessages = @()

function Write-WarningAndCollect {
    param([string]$Message)
    Write-Warning $Message
    $Global:WarningMessages += $Message
}

# Addons list now using FileID instead of hardcoded URLs
$Addons = @(
    @{ AddonType="Main"; Name='HarvestRoute'; FileID=3356 }
    @{ AddonType="Main"; Name='Destinations'; FileID=667 }
    @{ AddonType="Main"; Name='Advanced Filters'; FileID=2215 }
    @{ AddonType="Main"; Name='TamrielTradeCentre'; FileID=1245 }
    @{ AddonType="Main"; Name='Auto Recharge'; FileID=1091 }
    @{ AddonType="Main"; Name='Enchantment Learner'; FileID=3059 }
    @{ AddonType="Main"; Name='Potion Maker (for Alchemy Crafting)'; FileID=405 }
    @{ AddonType="Main"; Name='Dolgubons Lazy Writ Crafter'; FileID=1346 }
    @{ AddonType="Main"; Name='HarvestMap'; FileID=57 }
    @{ AddonType="Main"; Name='SkyShards'; FileID=128 }
    @{ AddonType="Main"; Name='VotansMiniMap'; FileID=1399 }
    @{ Name='LibQRCode'; FileID=4102 }  
    @{ Name='LibPrice'; FileID=2204 }  
    @{ Name='LibScrollableMenu'; FileID=3546 }  
    @{ Name='LibFilters-3.0'; FileID=2343 }  
    @{ Name='CustomCompassPins'; FileID=185 }
    @{ Name='LibAddonMenu'; FileID=7 }
    @{ Name='LibAddonMenu-2.0'; FileID=7 }
    @{ Name='LibAsync'; FileID=2125 }
    @{ Name='LibChatMessage'; FileID=2382 }
    @{ Name='LibDebugLogger'; FileID=2275 }
    @{ Name='LibGPS'; FileID=601 }
    @{ Name='LibHarvensAddonSettings'; FileID=584 }
    @{ Name='LibLazyCrafting'; FileID=1594 }
    @{ Name='LibMainMenu-2.0'; FileID=2118 }
    @{ Name='LibMapData'; FileID=3353 }
    @{ Name='LibMapPing'; FileID=1302 }
    @{ Name='LibMapPins-1.0'; FileID=563 }
    @{ Name='MapPins'; FileID=1881 }
    @{ Name='LibCustomMenu'; FileID=1146 }
    @{ Name='LibAlchemyStation'; FileID=2628 }
)

function Get-LatestAddonUrlAndFilename {
    param([int]$fileID)

    $baseUrl = "https://cdn.esoui.com/downloads/file$fileID/"

    Write-Host "[INFO] Requesting latest addon info for fileID $fileID from $baseUrl"

    try {
        # Get the response headers without downloading the body
        $response = Invoke-WebRequest -Uri $baseUrl -MaximumRedirection 0 -ErrorAction Stop -Method Get

        $contentDisposition = $response.Headers['Content-Disposition']
        if ($contentDisposition -and $contentDisposition -match 'filename="?([^"]+)"?') {
            $fileName = $matches[1]
            Write-Host "[INFO] Latest filename detected: $fileName"
            return @{ Url = $baseUrl; FileName = $fileName }
        }
        else {
            Write-WarningAndCollect "No Content-Disposition filename found for fileID $fileID. Using fallback filename."
            return @{ Url = $baseUrl; FileName = "Addon_$fileID.zip" }
        }
    }
    catch {
        Write-WarningAndCollect ("Error fetching latest URL for FileID {0}: {1}" -f $fileID, $_.Exception.Message)
        return $null
    }
}

function Get-DependenciesFromAddonFile {
    param([string]$AddonFilePath)

    if (-not (Test-Path $AddonFilePath)) {
        Write-WarningAndCollect "Addon file not found: $AddonFilePath"
        return @()
    }

    $lines = Get-Content $AddonFilePath
    $dependencies = @()

    foreach ($line in $lines) {
        if ($line -match '^##\s*(PCDependsOn|ConsoleDependsOn|DependsOn):\s*(.+)$') {
            $depLine = $matches[2]
            $depParts = $depLine -split '\s+'
            foreach ($dep in $depParts) {
                if ($dep -match '^([^>=]+)') {
                    $depName = $matches[1]
                    $dependencies += $depName
                }
            }
        }
    }

    return $dependencies | Select-Object -Unique
}

# GUI Addon Picker - select which addons to install/update
$selectionObjects = $Addons | ForEach-Object {
    [PSCustomObject]@{
        Type   = $_.AddonType
        Name   = $_.Name
        FileID = "$($_.FileID)"  # Cast FileID to string
    }
} | Sort-Object @{ Expression = { if ($_.Type -eq 'Main') { 0 } else { 1 } } }, Name

$selection = $selectionObjects | Out-GridView -Title "Select ESO Addon(s) to Install or Update" -PassThru

if (-not $selection) {
    Write-WarningAndCollect "No addons selected. Exiting."
    exit
}

# Map selection back to original addon objects by Name
$SelectedAddons = @()
foreach ($sel in $selection) {
    $match = $Addons | Where-Object { $_.Name -eq $sel.Name -and $_.FileID -eq $sel.FileID }
    if ($match) {
        $SelectedAddons += $match
    }
}


# Keep track of already installed addons to avoid duplicate installs via dependencies
$InstalledAddons = @{}

function Install-Addon {
    param($Addon)

    if ($InstalledAddons.ContainsKey($Addon.Name)) {
        Write-Host "[INFO] $($Addon.Name) already installed or queued. Skipping."
        return
    }

    $InstalledAddons[$Addon.Name] = $true

    $Name = $Addon.Name
    $FileID = $Addon.FileID

    Write-Host "`n[INSTALL] Starting install/update of $Name..."

    $info = Get-LatestAddonUrlAndFilename -fileID $FileID
    if (-not $info) {
        Write-WarningAndCollect ("Skipping {0} due to failure retrieving latest info." -f $Name)
        return
    }

    $url = $info.Url
    $fileName = $info.FileName
    $zipPath = Join-Path $DownloadFolder $fileName

    # Download ZIP if missing
    if (-not (Test-Path $zipPath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Write-Host "Downloaded $Name to $zipPath"
        }
        catch {
            Write-WarningAndCollect "Failed to download ${Name}: $_"
            return
        }
    }
    else {
        Write-Host "[INFO] File already downloaded: $zipPath"
    }

    # Extract ZIP to temp and move to AddOns
    try {
        $tempExtractPath = Join-Path $env:TEMP "$Name-temp"
        if (Test-Path $tempExtractPath) { Remove-Item -Recurse -Force $tempExtractPath }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempExtractPath -Force

        $extractedFolders = Get-ChildItem -Path $tempExtractPath -Directory
        if ($extractedFolders.Count -eq 1) {
            $extractedFolderName = $extractedFolders[0].Name
            $addonExtractPath = Join-Path $AddonFolder $extractedFolderName
            if (Test-Path $addonExtractPath) { Remove-Item -Recurse -Force $addonExtractPath }
            Move-Item -LiteralPath $extractedFolders[0].FullName -Destination $AddonFolder
        }
        else {
            foreach ($folder in $extractedFolders) {
                $dest = Join-Path $AddonFolder $folder.Name
                if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
                Move-Item -LiteralPath $folder.FullName -Destination $AddonFolder
            }
            $extractedFolderName = $null
        }

        Remove-Item -Recurse -Force $tempExtractPath
        Write-Host "Extracted $Name to AddOns folder"
    }
    catch {
        Write-WarningAndCollect "Failed to extract ${Name}: $_"
        return
    }

    # Determine search root based on extracted folder name
    if ($extractedFolderName) {
        $searchRoot = Join-Path $AddonFolder $extractedFolderName
    }
    else {
        $searchRoot = $AddonFolder
    }

    $addonFolderName = Split-Path $searchRoot -Leaf

    $addonFiles = Get-ChildItem -Path $searchRoot -Include '*.addon','*.txt' -File -Recurse
    $addonFile = $addonFiles | Where-Object {
        ($_.BaseName -eq $addonFolderName) -and
        (($_ | Get-Content -TotalCount 10) -match '^##\s*(Title|APIVersion|DependsOn|PCDependsOn|ConsoleDependsOn)')
    } | Select-Object -First 1

    if (-not $addonFile) {
        Write-WarningAndCollect "No metadata file (.addon or .txt) found for $Name. Skipping dependency check."
        return
    }

    # Parse dependencies
    $deps = Get-DependenciesFromAddonFile -AddonFilePath $addonFile.FullName
    if ($deps.Count -gt 0) {
        Write-Host "[INFO] Dependencies for ${Name}: $($deps -join ', ')"
        foreach ($depName in $deps) {
            $depAddon = $Addons | Where-Object { $_.Name -eq $depName }
            if ($depAddon) {
                Install-Addon -Addon $depAddon
            }
            else {
                Write-WarningAndCollect "Dependency $depName not found in addon list. Please install it manually if needed."
            }
        }
    }

    Write-Host "✅ $Name installed successfully."
}

# Install all selected addons (and their dependencies)
foreach ($addon in $SelectedAddons) {
    Install-Addon -Addon $addon
}

# At the very end - show all warnings collected during the run
if ($Global:WarningMessages.Count -gt 0) {
    Write-Host "`n===== ALL WARNINGS SUMMARY ====="
    foreach ($msg in $Global:WarningMessages) {
        Write-Host "WARNING: $msg"
    }
    Write-Host "==============================`n"
}
