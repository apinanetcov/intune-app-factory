$app = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
                         "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "Egnyte*" }

if ($app) {
    Write-Output "DETECTED: $($app.DisplayName) $($app.DisplayVersion)"
    exit 0
} else {
    Write-Output "NOT DETECTED"
    exit 1
}