param(
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$ArtifactFolder,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$ClientSecret
)

$ErrorActionPreference = "Stop"

if (-not (Get-Module -ListAvailable -Name IntuneWin32App)) {
    Install-Module -Name IntuneWin32App -Force -AcceptLicense -Scope CurrentUser
}
Import-Module IntuneWin32App

$app = Get-Content (Join-Path $ArtifactFolder "app.json") -Raw | ConvertFrom-Json
$intuneWinFile = Get-ChildItem -Path $ArtifactFolder -Filter "*.intunewin" | Select-Object -First 1

Write-Host "Connecting to Microsoft Graph..."
Connect-MSIntuneGraph -TenantID $TenantId -ClientID $ClientId -ClientSecret $ClientSecret

$metaData = Get-IntuneWin32AppMetaData -FilePath $intuneWinFile.FullName

$requirementRule = New-IntuneWin32AppRequirementRule -Architecture $app.Architecture `
                                                       -MinimumSupportedWindowsRelease $app.MinimumSupportedWindowsRelease

$detectionRule = New-IntuneWin32AppDetectionRuleMSI -ProductCode $metaData.ApplicationInfo.MsiInfo.MsiProductCode

$existing = Get-IntuneWin32App -DisplayName $app.DisplayName -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "App '$($app.DisplayName)' already exists (ID: $($existing.id)) — updating package"
    Set-IntuneWin32App -ID $existing.id `
                        -Description $app.Description `
                        -Publisher $app.Publisher `
                        -InformationURL $app.InformationURL `
                        -PrivacyURL $app.PrivacyURL
    Update-IntuneWin32AppPackageFile -ID $existing.id -FilePath $intuneWinFile.FullName
    $win32App = Get-IntuneWin32App -ID $existing.id
} else {
    Write-Host "Creating new Win32 app '$($app.DisplayName)'"
    $win32App = Add-IntuneWin32App -FilePath $intuneWinFile.FullName `
                                    -DisplayName $app.DisplayName `
                                    -Description $app.Description `
                                    -Publisher $app.Publisher `
                                    -InstallExperience $app.InstallExperience `
                                    -RestartBehavior $app.RestartBehavior `
                                    -DetectionRule $detectionRule `
                                    -RequirementRule $requirementRule `
                                    -InformationURL $app.InformationURL `
                                    -PrivacyURL $app.PrivacyURL `
                                    -CompanyPortalFeaturedApp $false
}

Write-Host "Assigning to group '$($app.AssignmentGroupName)'"

# Ensure Microsoft.Graph modules are available
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module -Name Microsoft.Graph.Authentication -Force -AcceptLicense -Scope CurrentUser
}
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Groups)) {
    Install-Module -Name Microsoft.Graph.Groups -Force -AcceptLicense -Scope CurrentUser
}
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups

# Authenticate Microsoft Graph using the same credentials
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -NoWelcome -ErrorAction Stop

$group = Get-MgGroup -Filter "displayName eq '$($app.AssignmentGroupName)'" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $group) {
    throw "Assignment group '$($app.AssignmentGroupName)' not found in Entra ID - create it first."
}

Write-Host "Found group '$($app.AssignmentGroupName)' (ID: $($group.id))"

Add-IntuneWin32AppAssignmentGroup -ID $win32App.id `
                                   -GroupID $group.id `
                                   -Intent "required" `
                                   -Notification "showAll"
Write-Host "Published '$($app.DisplayName)' (ID: $($win32App.id)) and assigned to $($app.AssignmentGroupName)"