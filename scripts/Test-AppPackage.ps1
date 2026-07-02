param(
    [Parameter(Mandatory)][string]$AppName,
    [Parameter(Mandatory)][string]$ArtifactFolder
)

$ErrorActionPreference = "Stop"

$appJson = Get-Content (Join-Path $ArtifactFolder "app.json") -Raw | ConvertFrom-Json
$setupFile = Join-Path $ArtifactFolder $appJson.SetupFileName
$detectionScript = Join-Path $ArtifactFolder "test-detection.ps1"

function Test-Detection {
    $result = & $detectionScript
    Write-Host $result
    return $LASTEXITCODE -eq 0
}

Write-Host "=== INSTALL ==="
if ($appJson.InstallerType -eq "MSI") {
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$setupFile`" /qn /norestart" -Wait -PassThru
} else {
    throw "InstallerType '$($appJson.InstallerType)' not yet handled by Test-AppPackage.ps1 — add EXE branch here."
}

if ($proc.ExitCode -notin 0, 3010) {
    throw "Install failed with exit code $($proc.ExitCode)"
}
Start-Sleep -Seconds 15

Write-Host "=== VERIFY INSTALLED ==="
if (-not (Test-Detection)) {
    throw "TEST FAILED: app not detected after install"
}
Write-Host "PASS: detected after install"

Write-Host "=== UNINSTALL ==="
if ($appJson.InstallerType -eq "MSI") {
    # Pull product code straight from the MSI so we don't hardcode it
    $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $msiDb = $windowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstaller, @($setupFile, 0))
    $view = $msiDb.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $msiDb, ("SELECT Value FROM Property WHERE Property = 'ProductCode'"))
    $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)
    $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
    $productCode = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)

    $proc = Start-Process msiexec.exe -ArgumentList "/x $productCode /qn /norestart" -Wait -PassThru
    if ($proc.ExitCode -notin 0, 3010) {
        throw "Uninstall failed with exit code $($proc.ExitCode)"
    }
}
Start-Sleep -Seconds 15

Write-Host "=== VERIFY REMOVED ==="
if (Test-Detection) {
    throw "TEST FAILED: app still detected after uninstall"
}
Write-Host "PASS: not detected after uninstall"

Write-Host "ALL TESTS PASSED for $AppName"