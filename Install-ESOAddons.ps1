# Configuration
$DownloadFolder = "$env:USERPROFILE\Downloads\ESO-MM"
$AddOnFolder = "$env:USERPROFILE\OneDrive\Documents\Elder Scrolls Online\live\AddOns"

# Make sure folders exist
if (-not (Test-Path $DownloadFolder)) { New-Item -Path $DownloadFolder -ItemType Directory | Out-Null }
if (-not (Test-Path $AddOnFolder)) { Write-Warning "AddOn folder not found: $AddOnFolder"; exit }

# List of addons with their numeric fileID from ESOUI CDN
$Addons = @(
    @{ Name = 'Enchantment Learner'; FileID = 3059 }
    @{ Name = 'LibCustomMenu'; FileID = 1146 }
    @{ Name = 'LibAlchemyStation'; FileID = 2628 }
    @{ Name = 'Auto Recharge'; FileID = 1091 }
    @{ Name = 'Potion Maker (for Alchemy Crafting)'; FileID = 405 }
    @{ Name = 'Dolgubons Lazy Writ Crafter'; FileID = 1346 }
    @{ Name = 'HarvestMap'; FileID = 57 }
    @{ Name = 'SkyShards'; FileID = 128 }
    @{ Name = 'VotansMiniMap'; FileID = 1399 }
    @{ Name = 'CustomCompassPins'; FileID = 185 }
    @{ Name = 'LibAddonMenu'; FileID = 7 }
    @{ Name = 'LibAsync'; FileID = 2125 }
    @{ Name = 'LibChatMessage'; FileID = 2382 }
    @{ Name = 'LibDebugLogger'; FileID = 2275 }
    @{ Name = 'LibGPS'; FileID = 601 }
    @{ Name = 'LibHarvensAddonSettings'; FileID = 584 }
    @{ Name = 'LibLazyCrafting'; FileID = 1594 }
    @{ Name = 'LibMainMenu-2.0'; FileID = 2118 }
    @{ Name = 'LibMapData'; FileID = 3353 }
    @{ Name = 'LibMapPing'; FileID = 1302 }
    @{ Name = 'LibMapPins-1.0'; FileID = 563 }
    @{ Name = 'MapPins'; FileID = 1881 }
)

function Get-LatestAddonUrlAndFilename {
    param(
        [int]$fileID
    )

    $baseUrl = "https://cdn.esoui.com/downloads/file$fileID/"

    Write-Host "[INFO] Requesting latest addon info for fileID $fileID from $baseUrl"

    try {
        # Send request, get headers & raw content
        $response = Invoke-WebRequest -Uri $baseUrl -Method Head -ErrorAction Stop

        # We expect redirect to the actual file URL with filename, but ESOUI seems to serve the file directly
        # So do a GET with -MaximumRedirection 0 to catch redirect manually

        $response = Invoke-WebRequest -Uri $baseUrl -MaximumRedirection 0 -ErrorAction Stop -Method Get

        # Check if response has Content-Disposition header with filename
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
        Write-Warning "Error getting latest URL for fileID ${fileID}: $_"
        return $null
    }
}

function Download-And-InstallAddon {
    param(
        [string]$Name,
        [int]$FileID
    )

    Write-Host "`n=== Processing addon: $Name ==="

    $info = Get-LatestAddonUrlAndFilename -fileID $FileID
    if (-not $info) {
        Write-Warning "Skipping $Name due to failure retrieving latest info."
        return
    }

    $url = $info.Url
    $fileName = $info.FileName
    $zipPath = Join-Path $DownloadFolder $fileName

    # Download the ZIP if missing or you can add logic here to check file date/version
    if (-not (Test-Path $zipPath)) {
        Write-Host "[INFO] Downloading $Name from $url ..."
        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
            Write-Host "[SUCCESS] Downloaded $fileName"
        }
        catch {
            Write-Warning "Failed to download ${Name}: $_"
            return
        }
    }
    else {
        Write-Host "[INFO] File already downloaded: $zipPath"
    }

    # Extract to ESO AddOn folder
    Write-Host "[INFO] Extracting $fileName to $AddOnFolder ..."
    try {
        # Remove existing addon folder if exists to avoid old files lingering
        $extractPath = Join-Path $AddOnFolder $Name
        if (Test-Path $extractPath) {
            Write-Host "[INFO] Removing existing addon folder: $extractPath"
            Remove-Item -Path $extractPath -Recurse -Force
        }

        # Extract ZIP
        Expand-Archive -Path $zipPath -DestinationPath $AddOnFolder -Force
        Write-Host "[SUCCESS] Installed $Name"
    }
    catch {
        Write-Warning "Extraction failed for ${Name}: $_"
    }
}

# Main execution loop - choose which addons to install here
foreach ($addon in $Addons) {
    Download-And-InstallAddon -Name $addon.Name -FileID $addon.FileID
}

Write-Host "`nAll addons processed."
