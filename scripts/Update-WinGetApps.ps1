. "$PSScriptRoot\Get-WingetInstallerUrl.ps1"

$repoRoot = Join-Path $PSScriptRoot ".."

$changesMade = $false
$updatedApps = @()

Get-ChildItem "$repoRoot\apps" -Directory | ForEach-Object {

    try {

        $appJsonPath = Join-Path $_.FullName "app.json"

        if (-not (Test-Path $appJsonPath)) {
            return
        }

        $app = Get-Content $appJsonPath -Raw | ConvertFrom-Json

        if (:IsNullOrWhiteSpace($app.WingetPackageId)) {

            Write-Host "Skipping $($_.Name) - not WinGet managed"
            return

        }

        Write-Host ""
        Write-Host "Checking $($_.Name)"

        $latestInstallerUrl =
            Get-WingetInstallerUrl -PackageId $app.WingetPackageId

        if (:IsNullOrWhiteSpace($latestInstallerUrl)) {

            Write-Warning "Unable to retrieve installer URL for $($app.WingetPackageId)"
            return

        }

        $latestFileName =
            Split-Path $latestInstallerUrl -Leaf

        # Initial population
        if (:IsNullOrWhiteSpace($app.SourceUri)) {

            Write-Host "SourceUri is blank - populating from WinGet"

            $app.SourceUri = $latestInstallerUrl
            $app.SetupFileName = $latestFileName

            $app |
                ConvertTo-Json -Depth 20 |
                Set-Content $appJsonPath

            $updatedApps += $_.Name
            $changesMade = $true

            return
        }

        # Version update
        if ($app.SourceUri -ne $latestInstallerUrl) {

            Write-Host "Update found"
            Write-Host "Old: $($app.SourceUri)"
            Write-Host "New: $latestInstallerUrl"

            $app.SourceUri = $latestInstallerUrl
            $app.SetupFileName = $latestFileName

            $app |
                ConvertTo-Json -Depth 20 |
                Set-Content $appJsonPath

            $updatedApps += $_.Name
            $changesMade = $true
        }
        else {

            Write-Host "No update available"

        }

    }
    catch {

        Write-Warning "Failed processing app '$($_.Name)'"
        Write-Warning $_.Exception.Message

    }
}

if ($changesMade) {

    Write-Host ""
    Write-Host "Changes detected. Committing updates..."

    git config user.name "Intune App Factory Bot"
    git config user.email "intune-app-factory@company.com"

    git add apps

    $appTags = $updatedApps | ForEach-Object {
        "[app:$_]"
    }

    $commitMessage = "Automated WinGet updates $($appTags -join ' ')"

    git commit -m $commitMessage

    git push

}
else {

    Write-Host ""
    Write-Host "No application updates detected"

}