param(
    [Parameter(Mandatory)][string]$AppName,
    [string]$SharePointUser,
    [SecureString]$SharePointPassword
)

$ErrorActionPreference = "Stop"

$appFolder   = Join-Path $PSScriptRoot "..\apps\$AppName"
$appJsonPath = Join-Path $appFolder "app.json"

if (-not (Test-Path $appJsonPath)) {
    throw "No app.json found for '$AppName' at $appJsonPath"
}

$app = Get-Content $appJsonPath -Raw | ConvertFrom-Json

$sourceFolder = Join-Path $PSScriptRoot "..\build\$AppName\source"
$outputFolder = Join-Path $PSScriptRoot "..\build\$AppName\output"
New-Item -ItemType Directory -Path $sourceFolder -Force | Out-Null
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

$setupFilePath = Join-Path $sourceFolder $app.SetupFileName

Write-Host "Downloading installer from $($app.SourceUri)"
#Invoke-WebRequest -Uri $app.SourceUri -OutFile $setupFilePath -UseBasicParsing
# Handle SharePoint authentication if needed
if ($app.SourceUri -match "sharepoint.com" -and $SharePointUser -and $SharePointPassword) {
    Write-Host "Using SharePoint authentication..."
    $credential = New-Object System.Management.Automation.PSCredential("$SharePointUser", (ConvertTo-SecureString "$SharePointPassword" -AsPlainText -Force))
    Invoke-WebRequest -Uri $app.SourceUri -OutFile $setupFilePath -UseBasicParsing -Credential $credential
} else {
    Invoke-WebRequest -Uri $app.SourceUri -OutFile $setupFilePath -UseBasicParsing
}

Write-Host "Installing IntuneWin32App module (if needed)"
if (-not (Get-Module -ListAvailable -Name IntuneWin32App)) {
    Install-Module -Name IntuneWin32App -Force -AcceptLicense -Scope CurrentUser
}
Import-Module IntuneWin32App

Write-Host "Building .intunewin package"
$package = New-IntuneWin32AppPackage -SourceFolder $sourceFolder `
                                      -SetupFile $app.SetupFileName `
                                      -OutputFolder $outputFolder `
                                      -Force

Write-Host "Package created at $($package.Path)"

# Copy app.json + test-detection.ps1 alongside the package so later
# stages don't need to re-clone the repo for metadata.
Copy-Item $appJsonPath $outputFolder -Force
$detectionScript = Join-Path $appFolder "test-detection.ps1"
if (Test-Path $detectionScript) {
    Copy-Item $detectionScript $outputFolder -Force
}
# Keep the raw installer too — the test stage installs it directly
# rather than re-extracting the .intunewin (faster, simpler).
Copy-Item $setupFilePath $outputFolder -Force

Write-Host "Build artifacts staged in $outputFolder"