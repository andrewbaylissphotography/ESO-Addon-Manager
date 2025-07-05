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

# Updated Addons list
$Addons = @(
    @{AddonType="Main"; Name='Dolgubons Lazy Writ Crafter'; Url='https://cdn.esoui.com/downloads/file1346/DolgubonsLazyWritCreator-4.0.1.3.zip'}
    @{AddonType="Main"; Name='HarvestMap'; Url='https://cdn.esoui.com/downloads/file57/HarvestMap-3_16_2.zip'}
    @{AddonType="Main"; Name='SkyShards'; Url='https://cdn.esoui.com/downloads/file128/SkyShards_v1059_2.zip'; }
    @{AddonType="Main"; Name='VotansMiniMap'; Url='https://cdn.esoui.com/downloads/file1399/VotansMiniMap_v2.1.5.zip'}
    @{Name='CustomCompassPins'; Url='https://cdn.esoui.com/downloads/file185/CustomCompassPins_v137.zip'}
    @{Name='LibAddonMenu'; Url='https://cdn.esoui.com/downloads/file7/LibAddonMenu-2.0r40.zip'}
    @{Name='LibAddonMenu-2.0'; Url='https://cdn.esoui.com/downloads/file7/LibAddonMenu-2.0r40.zip'}
    @{Name='LibAsync'; Url='https://cdn.esoui.com/downloads/file2125/LibAsync_v3.0.2.zip'}
    @{Name='LibChatMessage'; Url='https://cdn.esoui.com/downloads/file2382/LibChatMessage_1_2_2.zip'}
    @{Name='LibDebugLogger'; Url='https://cdn.esoui.com/downloads/file2275/LibDebugLogger_2_5_2.zip'}
    @{Name='LibGPS'; Url='https://cdn.esoui.com/downloads/file601/LibGPS_3_3_3.zip'}
    @{Name='LibHarvensAddonSettings'; Url='https://cdn.esoui.com/downloads/file584/LibHarvensAddonSettings_v2.0.6.zip'}
    @{Name='LibLazyCrafting'; Url='https://cdn.esoui.com/downloads/file1594/LibLazyCrafting-4.024.zip'}
    @{Name='LibMainMenu-2.0'; Url='https://cdn.esoui.com/downloads/file2118/LibMainMenu-2.0_v4.4.0.zip'}
    @{Name='LibMapData'; Url='https://cdn.esoui.com/downloads/file3353/LibMapData_v117.zip'}
    @{Name='LibMapPing'; Url='https://cdn.esoui.com/downloads/file1302/LibMapPing_2_1_0.zip'}
    @{Name='LibMapPins-1.0'; Url='https://cdn.esoui.com/downloads/file563/LibMapPins_v10045.zip'}
    @{Name='MapPins'; Url='https://cdn.esoui.com/downloads/file1881/1750886267-MapPins.zip'}
)

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
    $Url = $Addon.Url

    Write-Host "Starting install of $Name..."

    $zipPath = Join-Path $DownloadFolder "$Name.zip"

    # Download ZIP
    try {
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing
        Write-Host "Downloaded $Name to $zipPath"
    }
    catch {
        Write-Warning "Failed to download ${Name}: $_"
        return
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
        Url  = $_.Url
    }
} | Sort-Object -Property Type -Descending |
    Out-GridView -Title "Select ESO Addon(s) to Install" -PassThru

if (-not $selection) {
    Write-Warning "No addons selected. Exiting."
    exit
}

foreach ($addon in $selection) {
    Install-Addon -Addon $addon
}
