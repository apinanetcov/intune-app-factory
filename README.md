# intune-app-factory
Use for automated Intunewin Packages
Here's the updated README section to include the SharePoint authorization information:

```markdown
# Intune App Factory

Automated deployment pipeline for packaging and publishing applications to Microsoft Intune.

## Overview

This repository contains scripts and configurations to build, test, and deploy Windows applications as Win32 packages to Microsoft Intune. The workflow is triggered on push events and automatically handles the entire deployment lifecycle.

## Repository Structure

```
intune-app-factory/
├── .github/
│   └── workflows/
│       └── intune-app.yml              # GitHub Actions workflow
├── apps/                               # Application definitions
│   ├── GoogleChrome/
│   │   ├── app.json                    # App configuration
│   │   └── test-detection.ps1          # Detection rule test script
│   └── Egnyte/
│       ├── app.json
│       └── test-detection.ps1
├── scripts/                            # PowerShell deployment scripts
│   ├── Build-IntuneWinPackage.ps1      # Packages app as .intunewin
│   ├── Test-AppPackage.ps1             # Validates package integrity
│   └── Publish-IntuneApp.ps1           # Deploys to Intune
└── terraform/                          # Infrastructure as Code (future use)
```

## Adding a New Application

### Step 1: Create the App Directory

Create a new folder under `apps/` for your application:

```bash
mkdir apps/YourAppName
```

### Step 2: Create `app.json`

Create an `app.json` file in the app directory with the application configuration. You can obtain the MSI installer in two ways:

**Option A: Remote MSI (via SourceUri from Vendor)**

If the vendor provides a direct download link to the MSI:

```json
{
  "Name": "YourAppName",
  "DisplayName": "Your App Display Name",
  "Publisher": "App Publisher",
  "Description": "Brief description of the application",
  "InstallerType": "MSI",
  "SourceUri": "https://example.com/path/to/installer.msi",
  "SetupFileName": "installer.msi",
  "Architecture": "x64",
  "MinimumSupportedWindowsRelease": "W10_1809",
  "Category": "CategoryName",
  "InformationURL": "https://example.com",
  "PrivacyURL": "https://example.com/privacy",
  "AssignmentGroupName": "SG-Intune-App-YourApp-Pilot",
  "InstallExperience": "system",
  "RestartBehavior": "suppress"
}
```

**Option B: MSI Hosted on SharePoint**

If the vendor does not provide a SourceUri, upload the MSI to the **[Intune-App-Factory SharePoint site]** in the **'Intune-App-Factory Installers'** folder, then use the SharePoint link as your `SourceUri`:

1. Upload the MSI to: [Intune-App-Factory > Intune-App-Factory Installers](https://1svh3d.sharepoint.com/:f:/s/Intune-App-Factory/IgBjWgVTSTCyRJcVYoI7WDyqAVdBDrpK6hrADok0PyT5RI8?e=NV3U0w)
2. Right-click the MSI file and select "Share"
3. Set sharing to **"People in [My Organization]"**
4. Copy the link and use it in your `app.json`:

```json
{
  "Name": "YourAppName",
  "DisplayName": "Your App Display Name",
  "Publisher": "App Publisher",
  "Description": "Brief description of the application",
  "InstallerType": "MSI",
  "SourceUri": "https://yourtenant.sharepoint.com/sites/intune-app-factory/Shared%20Documents/Intune-App-Factory%20Installers/YourApp.msi",
  "SetupFileName": "YourApp.msi",
  "Architecture": "x64",
  "MinimumSupportedWindowsRelease": "W10_1809",
  "Category": "CategoryName",
  "InformationURL": "https://example.com",
  "PrivacyURL": "https://example.com/privacy",
  "AssignmentGroupName": "SG-Intune-App-YourApp-Pilot",
  "InstallExperience": "system",
  "RestartBehavior": "suppress"
}
```

### Step 3: Create `test-detection.ps1`

Create a PowerShell script to test the detection rule. This validates that the app can be properly detected after installation:

```powershell
# Example detection rule test for MSI-based app
$productCode = "{PRODUCT-CODE-GUID}"
$installedApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.IdentifyingNumber -eq $productCode }

if ($installedApp) {
    Write-Host "✓ Application detected: $($installedApp.Name) $($installedApp.Version)"
    exit 0
} else {
    Write-Host "✗ Application not detected"
    exit 1
}
```

### Step 4: Update Assignment Group

Ensure the Entra ID security group specified in `AssignmentGroupName` exists. The group will be automatically found and the app assigned to it during deployment. Also, make sure that any devices to recieve the app are part of the group.

## Configuration

### GitHub Secrets

The workflow requires the following secrets to be configured in your GitHub repository settings:

- **`TENANT_ID`** - Your Azure tenant ID
- **`CLIENT_ID`** - Application (client) ID of your app registration
- **`CLIENT_SECRET`** - Client secret for the app registration
- **`SHAREPOINT_USER`** - Your SharePoint user email (required for apps hosted on SharePoint)
- **`SHAREPOINT_PASSWORD`** - Your SharePoint password or app password (required for apps hosted on SharePoint)

### Entra ID App Registration

Ensure your app registration has the following API permissions granted:

- **Microsoft Graph**
  - `DeviceManagementApps.ReadWrite.All` (Application)
  - `Group.Read.All` (Application)

Admin consent must be granted for these permissions.

### SharePoint Authentication

The workflow automatically detects SharePoint URLs and authenticates using the `SHAREPOINT_USER` and `SHAREPOINT_PASSWORD` secrets. Ensure these are configured in your GitHub repository settings.

**Note on MFA**: If your organization uses Multi-Factor Authentication (MFA), you may need to use an **app password** instead of your regular password. Contact your SharePoint administrator for assistance generating an app password.

## Deployment Workflow

The GitHub Actions workflow (`intune-app.yml`) performs the following steps:

1. **Build** - Packages the MSI into a `.intunewin` file using the Intune Win32 Content Prep Tool
   - Downloads the MSI from the provided `SourceUri` (with SharePoint authentication if needed)
2. **Test** - Validates the package integrity and runs detection rule tests
3. **Publish** - Deploys the app to Intune:
   - Creates a new Win32 app or updates an existing one
   - Assigns the app to the specified Entra ID security group
   - Sets installation and restart behavior

## Triggering a Deployment

Deployments are triggered automatically when changes are pushed to the repository. Modify any `app.json` file and push to trigger a new build and deployment.

```bash
git add apps/YourApp/app.json
git commit -m "Update YourApp version"
git push
```

## Troubleshooting

### SharePoint Download Failures

If you receive authentication errors when downloading from SharePoint:

1. Verify that `SHAREPOINT_USER` and `SHAREPOINT_PASSWORD` secrets are configured correctly
2. If using MFA, ensure you're using an app password, not your regular password
3. Confirm the MSI file is set to "People in [My Organization]" sharing
4. Check that your account has access to the SharePoint site

### App Not Found in Intune

Verify that:
- The workflow completed successfully (check GitHub Actions logs)
- The app definition in `app.json` is valid JSON
- The assignment group exists in Entra ID with the exact name specified
- The `SourceUri` is accessible and returns a valid MSI file

### MSI Detection Issues

Test the detection rule locally:

```powershell
cd apps/YourAppName
./test-detection.ps1
```

Ensure the product code or registry path in your detection rule is correct for the MSI.

### Authentication Failures

Verify that:
- GitHub secrets are configured correctly
- The app registration exists in your tenant
- The app registration has required API permissions with admin consent granted
- For SharePoint URLs, the `SHAREPOINT_USER` and `SHAREPOINT_PASSWORD` secrets are set

## MSI Storage

All MSI installers for applications without vendor-provided download links should be stored in the **[Intune-App-Factory SharePoint site]** under the **'Intune-App-Factory Installers'** folder. This centralized location makes it easy to manage, version, and share installer files across the team.

## Supported Application Types

Currently, this factory supports:

- **MSI-based applications** - Windows Installer packages

Future support planned for:
- EXE installers
- MSP patches
- LOB applications

## References

- [Microsoft Intune Win32 App Management](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management)
- [Intune Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool)
- [Microsoft Graph API - Groups](https://learn.microsoft.com/en-us/graph/api/resources/group)

## License

[License will be added here eventually if needed]

## Support

For issues or questions, please create a GitHub issue in this repository.
```

## Key Additions

✅ Added "MSI Hosted on SharePoint" option in Step 2  
✅ Added instructions for uploading MSI files to SharePoint  
✅ Added `SHAREPOINT_USER` and `SHAREPOINT_PASSWORD` to GitHub Secrets section  
✅ Added SharePoint Authentication configuration section with MFA note  
✅ Added troubleshooting section for SharePoint download failures  
✅ Added new "MSI Storage" section highlighting the centralized SharePoint location  