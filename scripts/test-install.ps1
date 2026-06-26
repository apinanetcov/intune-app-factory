param (
    [string]$AppPath
)

$app = Get-Content "$AppPath\app.json" | ConvertFrom-Json

# Install
Write-Host "Installing app..."
Start-Process $app.installCommand -Wait

# Validate
Write-Host "Running detection script..."
$detect = & "$AppPath\detection.ps1"

if (-not $detect) {
    throw "Detection failed"
}

# Optional uninstall test
Write-Host "Testing uninstall..."
Start-Process $app.uninstallCommand -Wait

Write-Host "Test passed ✅"