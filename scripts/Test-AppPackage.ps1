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
    $logFile = Join-Path $env:TEMP "$AppName-install.log"
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$setupFile`" /qn /norestart /L*v `"$logFile`"" -Wait -PassThru
    Write-Host "MSI log: $logFile"
} else {
    throw "InstallerType '$($appJson.InstallerType)' not yet handled by Test-AppPackage.ps1 — add EXE branch here."
}
if ($proc.ExitCode -notin 0,3010) {

    Write-Host "===== MSI LOG (LAST 100 LINES) ====="

    if (Test-Path $logFile) {
        Get-Content $logFile -Tail 100
    }

    throw "Install failed with exit code $($proc.ExitCode)"
}

#if ($proc.ExitCode -notin 0, 3010) {
#    throw "Install failed with exit code $($proc.ExitCode)"
#}
Start-Sleep -Seconds 15

Write-Host "=== VERIFY INSTALLED ==="
if (-not (Test-Detection)) {
    throw "TEST FAILED: app not detected after install"
}
Write-Host "PASS: detected after install"

Write-Host "=== UNINSTALL ==="
if ($appJson.InstallerType -eq "MSI") {
    $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $msiDb = $windowsInstaller.GetType().InvokeMember(
        "OpenDatabase",
        [System.Reflection.BindingFlags]::InvokeMethod,
        $null, $windowsInstaller, @([string]$setupFile, [int]0)
    )
    $view = $msiDb.GetType().InvokeMember(
        "OpenView",
        [System.Reflection.BindingFlags]::InvokeMethod,
        $null, $msiDb, @([string]"SELECT Value FROM Property WHERE Property = 'ProductCode'")
    )
    $view.GetType().InvokeMember(
        "Execute",
        [System.Reflection.BindingFlags]::InvokeMethod,
        $null, $view, @()
    )
    $record = $view.GetType().InvokeMember(
        "Fetch",
        [System.Reflection.BindingFlags]::InvokeMethod,
        $null, $view, @()
    )
    $productCode = $record.GetType().InvokeMember(
        "StringData",
        [System.Reflection.BindingFlags]::GetProperty,
        $null, $record, @([int]1)
    )

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
exit 0