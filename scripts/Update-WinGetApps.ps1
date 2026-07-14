. "$PSScriptRoot\Get-WingetInstallerUrl.ps1"

$repoRoot = Join-Path $PSScriptRoot ".."

$changesMade = $false

Get-ChildItem "$repoRoot\apps" -Directory | ForEach-Object {

    $appJsonPath = Join-Path $_.FullName "app.json"

    if (-not (Test-Path $appJsonPath)) {
        return
    }

    $app = Get-Content $appJsonPath -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($app.WingetPackageId)) {
        Write-Host "Skipping $($_.Name) - not WinGet managed"
        return
    }

    Write-Host ""
    Write-Host "Checking $($_.Name)"

    $latestInstallerUrl =
        Get-WingetInstallerUrl -PackageId $app.WingetPackageId

    $latestFileName =
        Split-Path $latestInstallerUrl -Leaf

    if ($app.SourceUri -eq $latestInstallerUrl) {

        Write-Host "No update available"

    }
    else {

        Write-Host "Update found"
        Write-Host "Old: $($app.SourceUri)"
        Write-Host "New: $latestInstallerUrl"

        $app.SourceUri = $latestInstallerUrl
        $app.SetupFileName = $latestFileName

        $app |
            ConvertTo-Json -Depth 20 |
            Set-Content $appJsonPath

        $changesMade = $true
    }
}

if ($changesMade) {

    Write-Host "Changes detected"

    git config user.name "Intune App Factory Bot"
    git config user.email "intune-app-factory@company.com"

    git add apps

    git commit -m "Automated Winget application updates: [app:$($_.Name)]"

    git push
}
else {

    Write-Host "No application updates detected"
}