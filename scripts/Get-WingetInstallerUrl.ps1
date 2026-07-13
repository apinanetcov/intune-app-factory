function Get-WingetInstallerUrl {
    param(
        [string]$PackageId
    )

    $packageParts = $PackageId.Split('.')

    $firstLetter = $packageParts[0].Substring(0,1).ToLower()

    $apiPath = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$firstLetter/$($packageParts -join '/')"

    $versions = Invoke-RestMethod -Uri $apiPath

    $latestVersion =
        $versions |
        Sort-Object Name -Descending |
        Select-Object -First 1

    $manifestApi =
        "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/$firstLetter/$($packageParts -join '/')/$($latestVersion.name)"

    $files = Invoke-RestMethod -Uri $manifestApi

    $installerManifest =
        $files |
        Where-Object { $_.name -like "*.installer.yaml" } |
        Select-Object -First 1

    $yaml = Invoke-RestMethod -Uri $installerManifest.download_url

    $installerUrl =
        ($yaml | Select-String "InstallerUrl:").Line.Replace("InstallerUrl:","").Trim()

    return $installerUrl
}