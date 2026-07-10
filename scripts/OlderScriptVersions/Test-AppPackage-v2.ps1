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
    $arguments = "/i `"$setupFile`" $($appJson.InstallArguments)"
    $proc = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
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

# Priority 1: Explicit uninstall command from app definition
if (-not [string]::IsNullOrWhiteSpace($appJson.UninstallCommand)) {

    Write-Host "Using UninstallCommand from app definition:"
    Write-Host $appJson.UninstallCommand

    $proc = Start-Process `
        -FilePath "cmd.exe" `
        -ArgumentList "/c $($appJson.UninstallCommand)" `
        -Wait `
        -PassThru

    if ($proc.ExitCode -notin 0,3010) {
        throw "Uninstall failed with exit code $($proc.ExitCode)"
    }
}
else {

    # Priority 2: Registry uninstall string
    $installedApp = Get-ItemProperty `
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" ,
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -like "*$($appJson.AppName)*"
        } |
        Select-Object -First 1

    if ($installedApp -and $installedApp.UninstallString) {

        Write-Host "Using registry UninstallString:"
        Write-Host $installedApp.UninstallString

        $proc = Start-Process `
            -FilePath "cmd.exe" `
            -ArgumentList "/c $($installedApp.UninstallString)" `
            -Wait `
            -PassThru

        if ($proc.ExitCode -notin 0,3010) {
            throw "Uninstall failed with exit code $($proc.ExitCode)"
        }
    }
    else {

        # Priority 3: MSI ProductCode fallback
        if ($appJson.InstallerType -eq "MSI") {

            Write-Host "No UninstallCommand or registry uninstall string found."
            Write-Host "Falling back to MSI ProductCode."

            $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer

            $msiDb = $windowsInstaller.GetType().InvokeMember(
                "OpenDatabase",
                [System.Reflection.BindingFlags]::InvokeMethod,
                $null,
                $windowsInstaller,
                @([string]$setupFile,[int]0)
            )

            $view = $msiDb.GetType().InvokeMember(
                "OpenView",
                [System.Reflection.BindingFlags]::InvokeMethod,
                $null,
                $msiDb,
                @([string]"SELECT Value FROM Property WHERE Property = 'ProductCode'")
            )

            $view.GetType().InvokeMember(
                "Execute",
                [System.Reflection.BindingFlags]::InvokeMethod,
                $null,
                $view,
                @()
            )

            $record = $view.GetType().InvokeMember(
                "Fetch",
                [System.Reflection.BindingFlags]::InvokeMethod,
                $null,
                $view,
                @()
            )

            $productCode = $record.GetType().InvokeMember(
                "StringData",
                [System.Reflection.BindingFlags]::GetProperty,
                $null,
                $record,
                @([int]1)
            )

            Write-Host "MSI ProductCode: $productCode"

            $proc = Start-Process `
                -FilePath "msiexec.exe" `
                -ArgumentList "/x $productCode /qn /norestart" `
                -Wait `
                -PassThru

            if ($proc.ExitCode -notin 0,3010) {
                throw "Uninstall failed with exit code $($proc.ExitCode)"
            }
        }
        else {
            throw "Unable to determine uninstall method."
        }
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