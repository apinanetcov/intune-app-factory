param (
    [string]$AppPath
)

Import-Module IntuneWin32App

$app = Get-Content "$AppPath\app.json" | ConvertFrom-Json
$package = Get-ChildItem "$AppPath\output\*.intunewin"

Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All"

New-IntuneWin32App `
    -FilePath $package.FullName `
    -DisplayName $app.name `
    -Description $app.description `
    -Publisher $app.publisher `
    -InstallCommandLine $app.installCommand `
    -UninstallCommandLine $app.uninstallCommand `
    -DetectionRuleScriptFile "$AppPath\detection.ps1"