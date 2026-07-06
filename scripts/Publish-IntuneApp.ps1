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
# Using Invoke-MSGraphOperation if Get-MSGraphAllPages isn't exposed in your module version
$group = (Invoke-MSGraphOperation -Get -APIVersion "v1.0" -Resource "groups?`$filter=displayName eq '$($app.AssignmentGroupName)'").value

if (-not $group) {
    throw "Assignment group '$($app.AssignmentGroupName)' not found in Entra ID — create it first."
}

Add-IntuneWin32AppAssignmentGroup -ID $win32App.id `
                                   -GroupID $group.id `
                                   -Intent "required" `
                                   -Notification "showAll"

Write-Host "Published '$($app.DisplayName)' (ID: $($win32App.id)) and assigned to $($app.AssignmentGroupName)"