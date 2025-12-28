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

# Addons list now using FileID instead of hardcoded URLs
$Addons = @(
    @{ AddonType="Main"; Name='Auto Recharge'; FileID=1091 }
    @{ AddonType="Main"; Name='Enchantment Learner'; FileID=3059 }
    @{ AddonType="Main"; Name='Potion Maker (for Alchemy Crafting)'; FileID=405 }
    @{ AddonType="Main"; Name='Dolgubons Lazy Writ Crafter'; FileID=1346 }
    @{ AddonType="Main"; Name='HarvestMap'; FileID=57 }
    @{ AddonType="Main"; Name='SkyShards'; FileID=128 }
    @{ AddonType="Main"; Name='VotansMiniMap'; FileID=1399 }
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
            Write-Warning "No Content-Disposition filename found for fileID $fileID. Using fallback filename."
            return @{ Url = $baseUrl; FileName = "Addon_$fileID.zip" }
        }
    }
    catch {
        Write-Warning ("Error fetching latest URL for FileID {0}: {1}" -f $fileID, $_.Exception.Message)
        return $null
    }
}

function Get-DependenciesFromAddonFile {
    param([string]$AddonFilePath)

    if (-not (Test-Path $AddonFilePath)) {
        Write-Warning "Addon file not found: $AddonFilePath"
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

function Install-Addon {
    param($Addon)

    $Name = $Addon.Name
    $FileID = $Addon.FileID

    Write-Host "Starting install of $Name..."

    $info = Get-LatestAddonUrlAndFilename -fileID $FileID
    if (-not $info) {
        Write-Warning ("Skipping {0} due to failure retrieving latest info." -f $Name)
        return
    }

    $url = $info.Url
    $fileName = $info.FileName
    $zipPath = Join-Path $DownloadFolder $fileName

    # Download ZIP
    if (-not (Test-Path $zipPath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
            Write-Host "Downloaded $Name to $zipPath"
        }
        catch {
            Write-Warning "Failed to download ${Name}: $_"
            return
        }
    }
    else {
        Write-Host "[INFO] File already downloaded: $zipPath"
    }

    # Extract ZIP using system temp directory
    try {
        $tempExtractPath = Join-Path $env:TEMP "$Name-temp"
        Write-Host "[INFO] Temp extract path: $tempExtractPath"

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
        Write-Warning "Failed to extract ${Name}: $_"
        return
    }

    # Determine search root for .addon file
    if ($extractedFolderName) {
        $searchRoot = Join-Path $AddonFolder $extractedFolderName
    }
    else {
        $searchRoot = $AddonFolder
    }

    # Find .addon file recursively
    $addonFile = Get-ChildItem -Path $searchRoot -Filter '*.addon' -Recurse | Select-Object -First 1
    if (-not $addonFile) {
        Write-Warning "No .addon file found for $Name, skipping dependency check"
        return
    }

    # Parse dependencies
    $deps = Get-DependenciesFromAddonFile -AddonFilePath $addonFile.FullName
    if ($deps.Count -gt 0) {
        Write-Host "Dependencies for ${Name}: $($deps -join ', ')"
        foreach ($depName in $deps) {
            $depAddon = $Addons | Where-Object { $_.Name -eq $depName }
            if ($depAddon) {
                Install-Addon -Addon $depAddon
            }
            else {
                Write-Warning "Dependency $depName not found in addons list."
            }
        }
    }

    Write-Host "✅ $Name installed successfully."
}

# GUI Addon Picker
$selection = $Addons | ForEach-Object {
    [PSCustomObject]@{
        Type = $_.AddonType
        Name = $_.Name
        FileID = $_.FileID
    }
} | Sort-Object -Property Type, -Descending
    Out-GridView -Title "Select ESO Addon(s) to Install" -PassThru

if (-not $selection) {
    Write-Warning "No addons selected. Exiting."
    exit
}

foreach ($addon in $selection) {
    Install-Addon -Addon $addon
}
