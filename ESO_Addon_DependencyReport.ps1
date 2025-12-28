# Paths (handles OneDrive, folder redirection)
$DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$AddonFolder   = Join-Path $DocumentsPath "Elder Scrolls Online\live\AddOns"
$DesktopPath   = [Environment]::GetFolderPath('Desktop')
$csvPath       = Join-Path $DesktopPath "ESO_Addon_Dependencies_Report.csv"

# Known addons list (to map FileIDs)
$KnownAddons = @(
    @{ Name='Auto Recharge'; FileID=1091 }
    @{ Name='CarosEnchantmentLearner'; FileID=3059 }
    @{ Name='PotionMaker'; FileID=405 }
    @{ Name='DolgubonsLazyWritCreator'; FileID=1346 }
    @{ Name='HarvestMap'; FileID=57 }
    @{ Name='SkyShards'; FileID=128 }
    @{ Name='VotansMiniMap'; FileID=1399 }
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
    @{ Name='DebugLogViewer'; FileID=2389 }
    @{ Name='SpentSkillPoints'; FileID=303 }
)

function Get-DependenciesFromAddonFile {
    param([string]$AddonFilePath)

    $dependencies = @()

    foreach ($line in Get-Content $AddonFilePath -ErrorAction SilentlyContinue) {
        if ($line -match '^##\s*(DependsOn|PCDependsOn|ConsoleDependsOn|OptionalDependsOn):\s*(.+)$') {
            $depParts = $matches[2] -split '\s+'
            foreach ($dep in $depParts) {
                if ($dep -match '^([^>=<]+)') {
                    $dependencies += $matches[1].Trim()
                }
            }
        }
    }

    return $dependencies | Select-Object -Unique
}

function Generate-DependencyReport {
    param (
        [string]$AddonFolder,
        [string]$OutputCsvPath,
        [array]$KnownAddons
    )

    $addonDirs = Get-ChildItem -Path $AddonFolder -Directory
    $report = @()

    foreach ($dir in $addonDirs) {
        $addonName = $dir.Name

        # Find metadata file
        $metadataFile = Get-ChildItem -Path $dir.FullName -Include '*.addon', '*.txt' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

        $deps = @()
        if ($metadataFile) {
            $deps = Get-DependenciesFromAddonFile -AddonFilePath $metadataFile.FullName
        } else {
            Write-Warning "No metadata file found for '$addonName'"
        }

        # Lookup addon FileID
        $addonEntry = $KnownAddons | Where-Object { $_.Name -eq $addonName }
        $addonFileID = if ($addonEntry) { $addonEntry.FileID } else { "unknown" }

        # Build dependency strings with FileIDs
        $depsWithIDs = foreach ($dep in $deps) {
            $depEntry = $KnownAddons | Where-Object { $_.Name -eq $dep }
            if ($depEntry) {
                "$($depEntry.Name) ($($depEntry.FileID))"
            } else {
                "$dep (unknown)"
            }
        }

        $depsString = if ($depsWithIDs.Count -gt 0) { $depsWithIDs -join ', ' } else { '(none)' }

        $report += [PSCustomObject]@{
            "Addon (FileID)"      = "$addonName ($addonFileID)"
            "Dependencies (FileID)" = $depsString
        }
    }

    $report | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "`n✅ Dependency report created: $OutputCsvPath"
}


# Run the report
Generate-DependencyReport -AddonFolder $AddonFolder -OutputCsvPath $csvPath -KnownAddons $KnownAddons
