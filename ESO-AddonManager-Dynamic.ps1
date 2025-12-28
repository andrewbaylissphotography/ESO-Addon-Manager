# Paths
$DownloadFolder = Join-Path $env:USERPROFILE "Downloads\ESO-MM"
$DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$AddonFolder = Join-Path $DocumentsPath "Elder Scrolls Online\live\AddOns"

Write-Host "`n[INFO] Download folder: $DownloadFolder"
Write-Host "[INFO] AddOn folder:    $AddonFolder`n"

if (-not (Test-Path $DownloadFolder)) { New-Item -Path $DownloadFolder -ItemType Directory | Out-Null }
if (-not (Test-Path $AddonFolder)) { New-Item -Path $AddonFolder -ItemType Directory | Out-Null }

# Addons list using FileIDs
$Addons = @(
    [PSCustomObject]@{ Name = 'Auto Recharge'; FileID = 1091 }
    [PSCustomObject]@{ Name = 'Potion Maker'; FileID = 405 }
    [PSCustomObject]@{ Name = 'Dolgubons Lazy Writ Crafter'; FileID = 1346 }
    [PSCustomObject]@{ Name = 'HarvestMap'; FileID = 57 }
    [PSCustomObject]@{ Name = 'SkyShards'; FileID = 128 }
    [PSCustomObject]@{ Name = 'VotansMiniMap'; FileID = 1399 }
    [PSCustomObject]@{ Name = 'CustomCompassPins'; FileID = 185 }
    [PSCustomObject]@{ Name = 'LibAddonMenu'; FileID = 7 }
    [PSCustomObject]@{ Name = 'LibAsync'; FileID = 2125 }
    [PSCustomObject]@{ Name = 'LibChatMessage'; FileID = 2382 }
    [PSCustomObject]@{ Name = 'LibDebugLogger'; FileID = 2275 }
    [PSCustomObject]@{ Name = 'LibGPS'; FileID = 601 }
    [PSCustomObject]@{ Name = 'LibHarvensAddonSettings'; FileID = 584 }
    [PSCustomObject]@{ Name = 'LibLazyCrafting'; FileID = 1594 }
    [PSCustomObject]@{ Name = 'LibMainMenu-2.0'; FileID = 2118 }
    [PSCustomObject]@{ Name = 'LibMapData'; FileID = 3353 }
    [PSCustomObject]@{ Name = 'LibMapPing'; FileID = 1302 }
    [PSCustomObject]@{ Name = 'LibMapPins-1.0'; FileID = 563 }
    [PSCustomObject]@{ Name = 'MapPins'; FileID = 1881 }
)

# Get latest .zip URL by resolving redirect
function Get-LatestAddonUrl {
    param([int]$fileID)

    $baseUrl = "https://cdn.esoui.com/downloads/file$fileID/"

    try {
        $request = [System.Net.HttpWebRequest]::Create($baseUrl)
        $request.Method = "GET"
        $request.AllowAutoRedirect = $false

        $response = $request.GetResponse()
        $response.Close()
        return $null
    }
    catch {
        $webResponse = $_.Exception.Response
        if ($webResponse.StatusCode -eq 302 -or $webResponse.StatusCode -eq 301) {
            return $webResponse.GetResponseHeader("Location")
        } else {
            Write-Warning "Unexpected error or status code for file${fileID}: $($_.Exception.Message)"
            return $null
        }
    }
}



# Determine local addon folder modified date
function Get-LocalAddonDate {
    param([string]$addonName)

    $addonPath = Join-Path $AddonFolder $addonName
    if (Test-Path $addonPath) {
        return (Get-Item $addonPath).LastWriteTime
    } else {
        return $null
    }
}

# Get remote modified date from headers
function Get-RemoteModifiedDate {
    param([string]$url)

    try {
        $head = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        return $head.Headers['Last-Modified']
    }
    catch {
        Write-Warning "Could not get remote modified date for $url"
        return $null
    }
}

# Build full addon info list
foreach ($addon in $Addons) {
    $url = Get-LatestAddonUrl -fileID $addon.FileID
    if ($url) {
        $addon | Add-Member -NotePropertyName Url -NotePropertyValue $url
        $addon | Add-Member -NotePropertyName RemoteModified -NotePropertyValue (Get-RemoteModifiedDate -url $url)
        $addon | Add-Member -NotePropertyName LocalModified -NotePropertyValue (Get-LocalAddonDate -addonName $addon.Name)
    } else {
        Write-Warning "Could not get latest URL for $($addon.Name)"
    }
}

# Show GUI for user to select which addons to install
$selection = $Addons | Sort-Object Name | Out-GridView -Title "Select ESO Addons to Install/Update" -PassThru

if (-not $selection) {
    Write-Warning "No addons selected. Exiting."
    exit
}

# Install or update addons
foreach ($addon in $selection) {
    $name = $addon.Name
    $url = $addon.Url
    $fileName = [System.IO.Path]::GetFileName($url)
    $zipPath = Join-Path $DownloadFolder $fileName

    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Write-Host "`n✅ Downloaded $name as $fileName"

        # Extract
        $tempPath = Join-Path $env:TEMP "$name-temp"
        if (Test-Path $tempPath) { Remove-Item -Recurse -Force $tempPath }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempPath -Force

        # Move folders
        $folders = Get-ChildItem -Path $tempPath -Directory
        foreach ($folder in $folders) {
            $dest = Join-Path $AddonFolder $folder.Name
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            Move-Item -Path $folder.FullName -Destination $AddonFolder
        }

        Remove-Item -Recurse -Force $tempPath
        Write-Host "✅ Installed $name successfully"
    }
    catch {
        Write-Warning "Failed to install ${name}: $_"
    }
}
