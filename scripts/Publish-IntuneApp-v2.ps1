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

$intuneWinFile = Get-ChildItem `
    -Path $ArtifactFolder `
    -Filter "*.intunewin" |
    Select-Object -First 1

if (-not $intuneWinFile) {
    throw "No .intunewin file found in $ArtifactFolder"
}

Write-Host "Connecting to Microsoft Graph..."

Connect-MSIntuneGraph `
    -TenantID $TenantId `
    -ClientID $ClientId `
    -ClientSecret $ClientSecret

$requirementRule = New-IntuneWin32AppRequirementRule `
    -Architecture $app.Architecture `
    -MinimumSupportedWindowsRelease $app.MinimumSupportedWindowsRelease

#
# Configure installer-specific settings
#
switch ($app.InstallerType) {

    "MSI" {

        Write-Host "Configuring MSI application..."

        $metaData = Get-IntuneWin32AppMetaData `
            -FilePath $intuneWinFile.FullName

        $detectionRule = New-IntuneWin32AppDetectionRuleMSI `
            -ProductCode $metaData.ApplicationInfo.MsiInfo.MsiProductCode

        $installCommand = $null
        $uninstallCommand = $null
    }

    "EXE" {

        Write-Host "Configuring EXE application..."

        $detectionScriptPath = Join-Path `
            $ArtifactFolder `
            "test-detection.ps1"

        if (-not (Test-Path $detectionScriptPath)) {
            throw "EXE app requires test-detection.ps1 in artifact folder."
        }

        if ([string]::IsNullOrWhiteSpace($app.InstallCommand)) {
            throw "EXE app requires InstallCommand in app.json."
        }

        if ([string]::IsNullOrWhiteSpace($app.UninstallCommand)) {
            throw "EXE app requires UninstallCommand in app.json."
        }

        $detectionRule = New-IntuneWin32AppDetectionRuleScript `
            -ScriptFile $detectionScriptPath `
            -EnforceSignatureCheck $false `
            -RunAs32Bit $false

        $installCommand = $app.InstallCommand.Replace(
            "%InstallerPath%",
            $app.SetupFileName
        )

        $uninstallCommand = $app.UninstallCommand

        Write-Host "Install Command:"
        Write-Host $installCommand

        Write-Host "Uninstall Command:"
        Write-Host $uninstallCommand
    }

    default {
        throw "Unsupported InstallerType '$($app.InstallerType)'."
    }
}

$existing = Get-IntuneWin32App `
    -DisplayName $app.DisplayName `
    -ErrorAction SilentlyContinue

if ($existing) {

    Write-Host "App '$($app.DisplayName)' already exists (ID: $($existing.id))"

    Set-IntuneWin32App `
        -ID $existing.id `
        -Description $app.Description `
        -Publisher $app.Publisher `
        -InformationURL $app.InformationURL `
        -PrivacyURL $app.PrivacyURL

    Write-Host "Updating package file..."

    Update-IntuneWin32AppPackageFile `
        -ID $existing.id `
        -FilePath $intuneWinFile.FullName

    $win32App = Get-IntuneWin32App `
        -ID $existing.id
}
else {

    Write-Host "Creating new Win32 app '$($app.DisplayName)'"

    if ($app.InstallerType -eq "MSI") {

        $win32App = Add-IntuneWin32App `
            -FilePath $intuneWinFile.FullName `
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
    else {

        $win32App = Add-IntuneWin32App `
            -FilePath $intuneWinFile.FullName `
            -DisplayName $app.DisplayName `
            -Description $app.Description `
            -Publisher $app.Publisher `
            -InstallCommandLine $installCommand `
            -UninstallCommandLine $uninstallCommand `
            -InstallExperience $app.InstallExperience `
            -RestartBehavior $app.RestartBehavior `
            -DetectionRule $detectionRule `
            -RequirementRule $requirementRule `
            -InformationURL $app.InformationURL `
            -PrivacyURL $app.PrivacyURL `
            -CompanyPortalFeaturedApp $false
    }
}

Write-Host "Assigning to group '$($app.AssignmentGroupName)'"

Connect-MgGraph `
    -TenantID $TenantId `
    -ClientSecretCredential (
        New-Object System.Management.Automation.PSCredential(
            "$ClientId",
            (ConvertTo-SecureString "$ClientSecret" -AsPlainText -Force)
        )
    ) `
    -NoWelcome

$group = Get-MgGroup `
    -Filter "displayName eq '$($app.AssignmentGroupName)'"

if (-not $group) {

    Write-Host "No matching group found."

    Get-MgGroup -Top 20 |
        Select-Object DisplayName, Id

    throw "Assignment group '$($app.AssignmentGroupName)' not found."
}

Write-Host "Found group '$($app.AssignmentGroupName)' (ID: $($group.id))"

Add-IntuneWin32AppAssignmentGroup `
    -ID $win32App.id `
    -Include `
    -GroupID $group.id `
    -Intent "required" `
    -Notification "showAll"

Write-Host "Published '$($app.DisplayName)' (ID: $($win32App.id)) and assigned to $($app.AssignmentGroupName)"