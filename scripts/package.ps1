param (
    [string]$AppPath
)

$source = Join-Path $AppPath "source"
$output = Join-Path $AppPath "output"

if (!(Test-Path $output)) {
    New-Item -ItemType Directory -Path $output | Out-Null
}

$setupFile = Get-ChildItem $source | Where-Object {$_.Extension -in ".exe",".msi"} | Select-Object -First 1

.\IntuneWinAppUtil.exe `
  -c $source `
  -s $setupFile.Name `
  -o $output `
  -q

Write-Host "Packaging complete"