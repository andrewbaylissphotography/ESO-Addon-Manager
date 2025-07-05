# Set-ExecutionPolicy.ps1
# This script sets the execution policy to RemoteSigned for the current user

$ExecutionPolicy = Get-ExecutionPolicy
if ($ExecutionPolicy -ne 'RemoteSigned') {
    Write-Host "Setting execution policy to RemoteSigned for current user..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} else {
    Write-Host "Execution policy is already set to RemoteSigned."
}

# Optionally, you can also invoke the main script after setting the policy
$scriptPath = ".\ESOAddonManager.ps1"
if (Test-Path $scriptPath) {
    Write-Host "Running the ESO Addon Manager script..."
    .\ESOAddonManager.ps1
} else {
    Write-Host "The script 'ESOAddonManager.ps1' was not found in this directory."
}
