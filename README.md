# Intune App Factory - NetCov Infrastructure Team
v1.0.0
## Overview

Intune App Factory provides a standardized process for packaging, validating, and deploying Win32 applications to Microsoft Intune.

The repository uses GitHub Actions to automate the complete application lifecycle:

1. Build a Win32 (`.intunewin`) package.
2. Test application installation and detection on a dedicated self-hosted runner.
3. Require manual approval before production deployment.
4. Upload the application to Microsoft Intune.
5. Assign the application to a pre-defined Entra ID / Intune group.
6. Automatically monitor WinGet-managed applications for new versions

This approach ensures all applications are validated before being made available to users and provides a consistent deployment experience across the organization.

---

## End-to-End Workflow

```text
Engineer
    |
    v
Clone Repository
    |
    v
Create Feature Branch
    |
    v
Add New App Folder
(apps/<AppName>)
    |
    v
Commit Changes
(commit message must contain [app:<AppName>])
    |
    v
Push Branch
    |
    v
Create Pull Request
    |
    v
Peer Review Required
(1 approval minimum)
    |
    v
Merge to Main
    |
    v
Build .intunewin Package
    |
    v
Install / Detection Test
on Self-Hosted Runner
    |
    v
Production Approval Gate
    |
    v
Publish to Intune
    |
    v
Assign to Deployment Group


WEEKLY WINGET UPDATE PROCESS:

Scheduled Workflow
    |
    v
Check WinGet Managed Apps
    |
    v
New Version Found
    |
    v
Create Branch
    |
    v
Create Pull Request
    |
    v
Review & Merge
    |
    v
Build Package
    |
    v
Test Install / Detection
    |
    v
Production Approval
    |
    v
Publish to Intune
```

---

## Repository Structure

```text
.
├── apps
│   └── <AppName>
│       ├── app.json
│       └── test-detection.ps1
│
├── scripts
│   ├── Build-IntuneWinPackage.ps1
│   ├── Test-AppPackage.ps1
│   └── Publish-IntuneApp.ps1
│
└── .github
    └── workflows
        └── intune-app-factory.yml
```

---

## Adding a New Application

### 1. Clone the Repository

```powershell
git clone <repository-url>
cd intune-app-factory
```

### 2. Create a Feature Branch

```powershell
git checkout -b add-7zip
```

### 3. Create a New Application Folder

Create a folder under the `apps` directory.

Example:

```text
apps/
└── 7-Zip/
    ├── app.json
    └── test-detection.ps1
```

---

## App.json Source Options:
Applications can be configured using either:
### Option 1 - WinGet Managed (Recommended)
Provide a WingetPackageId and leave both `SourceUri` and `SetupFileName` blank.

During the build process, Intune App Factory will:
- Query the official WinGet manifest repository.
- Retrieve the latest installer URL.
- Automatically populate:
    - SourceUri
    - SetupFileName
- Download the installer and continue packaging normally  
Example:
```json
{
  "Name": "Egnyte",
  "DisplayName": "Egnyte Desktop App",
  "Publisher": "Egnyte",
  "Description": "Egnyte Desktop Application",
  "InstallerType": "MSI",
  "WingetPackageId": "Egnyte.EgnyteDesktopApp",
  "SourceUri": "",
  "SetupFileName": "",
  "Architecture": "x64",
  "InstallArguments": "/qn /norestart",
  "AssignmentGroupName": "SG-Intune-App-Egnyte-Pilot",
  "InstallExperience": "system",
  "RestartBehavior": "suppress"
}
```

#### Finding the 'WingetPackageId' 
Using powershell, use (example):
```powershell
winget search Egnyte
#or
winget show Egnyte
```  
Example Output: 'Found Egnyte Desktop App [Egnyte.EgnyteDesktopApp]'
The value in the brackets for the 'WingetPackageId' 
```json
"WingetPackageId": "Egnyte.EgnyteDesktopApp"
```
Benefits
- No need to manually locate download URLs.
- Automatically retrieves the latest version published in WinGet.
- Reduces application maintenance effort.
- Ensures the latest vendor installer is used during packaging.

### Option 2 - Static Installer Source (Vendor or Sharepoint Hosted)
Provide both:
```json
{
    "SourceUri": "",
    "SetupFileName": "",
}
```
This method should be used when:  
- A specific version must be deployed.
- The application is not available in WinGet.
- Testing or validation requires a fixed installer version.
- Internal/private installers are used.  
Example:
```json
{
  "Name": "7-Zip",
  "DisplayName": "7-Zip",
  "Publisher": "7-Zip",
  "InstallerType": "MSI",
  "SourceUri": "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.msi",
  "SetupFileName": "7z2602-x64.msi",
  "Architecture": "x64",
  "InstallArguments": "/qn /norestart"
}
```
#### Source Selection Rules:

| Scenario | WingetPackageId | SourceUri | SetupFileName |
|-----------|----------------|-----------|---------------|
| Use latest version from WinGet | Required | Leave blank | Leave blank |
| Deploy a specific vendor version | Not required | Required | Required |
| Internal SharePoint-hosted installer | Not required | Required | Required |
| Application not available in WinGet | Not required | Required | Required |  


**Important:** If `WingetPackageId` is specified, the build process automatically retrieves the latest installer URL and filename from the WinGet repository and populates the `SourceUri` and `SetupFileName` values during the build stage.

## App.json Templates

Each application must contain an `app.json` file.

### MSI Example (Using WinGet):

```json
{
  "Name": "Egnyte", // REQUIRED
  "DisplayName": "Egnyte Desktop App", // REQUIRED
  "WingetPackageId": "Egnyte.EgnyteDesktopApp", // REQUIRED
  "Publisher": "Egnyte", // REQUIRED
  "Description": "Egnyte Desktop application for file sync and sharing.",
  "InstallerType": "MSI", // REQUIRED -- cannot be empty!
  "SourceUri": "", //leave empty
  "SetupFileName": "", //leave empty
  "Architecture": "x64", // REQUIRED
  "InstallArguments": "/qn ED_UPDATE_ON_BOOT=1", // REQUIRED
  "MinimumSupportedWindowsRelease": "W10_1809", // REQUIRED
  "Category": "Productivity",
  "InformationURL": "https://www.egnyte.com",
  "PrivacyURL": "https://www.egnyte.com/privacy",
  "AssignmentGroupName": "SG-Intune-App-Egnyte-Pilot", // REQUIRED
  "InstallExperience": "system", // REQUIRED
  "RestartBehavior": "suppress" // REQUIRED
}
```
### EXE Example (Static Installer & Vendor Url):
```json
{
  "Name": "VLC", // REQUIRED
  "DisplayName": "VLC Media Player", // REQUIRED
  "Publisher": "VideoLAN", // REQUIRED
  "Description": "Open source media player.",
  "InstallerType": "EXE", // REQUIRED -- cannot be empty!
  "SourceUri": "https://downloads.videolan.org/vlc/3.0.23/win64/vlc-3.0.23-win64.exe", // REQUIRED
  "SetupFileName": "vlc-3.0.23-win64.exe", // REQUIRED
  "Architecture": "x64", // REQUIRED
  "InstallCommand": "\"%InstallerPath%\" /S", // REQUIRED
  "UninstallCommand": "\"C:\\Program Files\\VideoLAN\\VLC\\uninstall.exe\" /S", // REQUIRED
  "MinimumSupportedWindowsRelease": "W10_1809", // REQUIRED
  "Category": "Multimedia",
  "InformationURL": "https://www.videolan.org",
  "PrivacyURL": "https://www.videolan.org",
  "AssignmentGroupName": "SG-Intune-App-VLC-Pilot", // REQUIRED
  "InstallExperience": "system", // REQUIRED
  "RestartBehavior": "suppress" // REQUIRED
}
```
Vendor Download URLs
When using external download URLs, ensure the URL points directly to the installer binary. Many vendor websites use redirect pages or download landing pages that may result in HTML content being downloaded instead of the installer.

A good validation method is to verify:
- The downloaded file size matches the vendor's published installer size.
- The file executes manually.
- The automated test phase successfully launches the installer. For some vendors, direct binary URLs may need to be obtained using browser developer tools (F12 → Network tab) while initiating the download.  

### Sharepoint Hosted Installer (Exe or MSI):
Upload the installer to the Intune App Factory SharePoint site.
Use the following value in app.json:
```json
"SourceUri": "https://1svh3d.sharepoint.com/sites/Intune-App-Factory"
```
The build process will:
- Authenticate using PnP PowerShell.
- Retrieve the installer from SharePoint.
- Match the file using the SetupFileName value.  

Example:
```json
{
  "SourceUri": "https://1svh3d.sharepoint.com/sites/Intune-App-Factory",
  "SetupFileName": "7z2602-x64.msi"
}
```
### Important Fields

| Field | Description |
|---------|-------------|
| DisplayName | Name displayed in Intune |
| WingetPackageId | Optional. WinGet package identifier (for example, Egnyte.EgnyteDesktopApp). When specified, Intune App Factory automatically retrieves the installer URL and filename from the WinGet repository. |
| SourceUri | Installer download location |
| SetupFileName | Installer filename |
| InstallerType | Supported values: MSI or EXE |
| InstallArguments | MSI only. Silent install arguments used with msiexec |
| InstallCommand | EXE only. Used during testing and publishing |
| UninstallCommand | EXE only. Used during testing and publishing |
| AssignmentGroupName | Intune group to receive the application |
| Architecture | x64, x86, etc. |
| MinimumSupportedWindowsRelease | Minimum supported Windows version |

---

## Automatic WinGet Updates

Applications configured with a `WingetPackageId` are automatically checked for updates once per week.

### Update Process

```text
Scheduled Workflow
        ↓
Check WinGet Repository
        ↓
New Version Available?
        ↓
       Yes
        ↓
Update app.json
        ↓
Create Branch
        ↓
Create Pull Request
        ↓
Engineering Review
        ↓
Merge Pull Request
        ↓
Build Package
        ↓
Test Installation
        ↓
Production Approval
        ↓
Publish to Intune
```

### What Gets Updated

When a newer installer version is detected, the automation updates:

```json
{
  "SourceUri": "",
  "SetupFileName": ""
}
```

using the latest installer information from the WinGet repository.

### Pull Request Creation

The weekly update process does not push directly to the `main` branch.

Instead it:

1. Creates a new branch.
2. Updates the affected application definitions.
3. Creates a Pull Request.
4. Waits for normal engineering review and approval.

After the Pull Request is merged, the standard Intune App Factory deployment workflow automatically begins.

### Applications Excluded from Automatic Updates

Applications are not automatically updated when:

- `WingetPackageId` is not specified.
- The application uses a manually managed `SourceUri`.
- The application uses a SharePoint-hosted installer.
- The application version is intentionally pinned.

These applications continue to follow the normal manual update process.
---

## Installer Types
The Intune App Factory currently supports:
### MSI Installers
For MSI packages:
```json
{
  "InstallerType": "MSI",
  "InstallArguments": "/qn /norestart"
}
```
Requirements:
- Installer file must be an .msi
- Silent install arguments should be supplied using **InstallArguments**.
- Automated testing installs using `msiexec`.
- Detection uses MSI product code when publishing to Intune.

### EXE Installers
For executable installers:
```json
{
  "InstallerType": "EXE",
  "InstallCommand": "\"%InstallerPath%\" /S",
  "UninstallCommand": "\"C:\\Program Files\\Vendor\\App\\uninstall.exe\" /S"
}
```
Requirements:
- Installer file must be an `.exe`.
- Silent install command must be provided.
- Silent uninstall command must be provided.
- Detection is performed using the application's `test-detection.ps1` script.

#### %InstallerPath%
For EXE installers, the token `%InstallerPath%` is automatically replaced during testing and publishing with the actual installer executable.
Example:
```json
{
  "InstallCommand": "\"%InstallerPath%\" /S"
}
```
becomes `"vlc-3.0.23-win64.exe" /S` when published to Intune.

---

## Detection Script

Each application must include a detection script named:

```text
test-detection.ps1
```

The script is used during automated validation.

### Requirements

The script must:

- Return exit code `0` when the application is installed.
- Return exit code `1` when the application is not installed.

Example:

```powershell
$app = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", `
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction Sil*ntlyContinue |
    Where-Object { *_.DisplayName*-like "7-Zip*" }

if ($app) {
    *rite-Output "DETECTED: $($app.Disp*ayName)"
    exit 0
}
else {
    W*ite-Output "NOT DETECTED"
    exit*1
}
```

---

# Commit Requirements

When adding or modifying an application, the commit message **MUST** contain:
```text
[app:<AppName>]
```
Example:
```text
Added new application definition [app:7-Zip]
```
The workflow uses this value to identify which application should be built and deployed.

---

## Pull Request Process

1. Push your feature branch. `git push origin <name of branch>`
2. Create a Pull Request. (via VSCode or GitHub)
3. Obtain approval from at least one reviewer.
4. Merge into `main` branch once approved.

A merge to `main` triggers the deployment workflow.
---

# Pipeline Stages

## Stage 1 - Build

The workflow:

1. Reads `app.json`.
2. Downloads the installer.
3. Builds a `.intunewin` package.
4. Produces artifacts containing:
   - `.intunewin`
   - `app.json`
   - `test-detection.ps1`
   - Original installer

Output location:

```text
build/<AppName>/output
```
---

## Stage 2 - Test

Testing occurs on the dedicated self-hosted runner.

The test process:

1. Installs the application.
2. Executes `test-detection.ps1`.
3. Verifies the application is detected.
4. Uninstalls the application.
5. Executes `test-detection.ps1` again.
6. Verifies the application is no longer detected.  

The deployment workflow continues only if all install, detection, and uninstall validation steps pass.

---

## Stage 3 - Production approval

After successful testing, **GitHub pauses the workflow at the production environment approval gate**.  
Deployment cannot proceed until an authorized approver approves the release.

---

## Stage 4 - Publish to Intune

The publish process:
1. Connects to Microsoft Intune.
2. Creates a new Win32 application if one does not already exist.
3. Updates an existing application if found.
4. Uploads the latest `.intunewin` package.
5. Applies application metadata.
6. Creates the appropriate install and uninstall commands.
7. Configures detection:
   - MSI product detection for MSI applications
   - Detection script-based validation for EXE applications
8. Assigns the application to the target deployment group defined in `AssignmentGroupName`.

Intune Deployment assignment type: `Required`

---

# Required GitHub Secrets

The following GitHub Actions secrets must be configured.
| Secret | Purpose |
|----------|----------|
| AZURE_CLIENT_ID | Application registration used for Intune uploads |
| AZURE_TENANT_ID | Azure tenant ID |
| AZURE_CLIENT_SECRET | Application secret used for Intune uploads |
| PNP_CLIENT_ID | PnP PowerShell application registration |
| PNP_CERT_LOCAL | Path to PnP certificate (.pfx) on the self-hosted runner |

---

## Self-Hosted Runner Requirements

The build and test jobs run on a self-hosted Windows runner with the labels:

```text
self-hosted
windows
intune-test
```
The runner must have:

- Network access to SharePoint (if used).
- PnP Powershell module installed (Install-Module PnP.PowerShell)
- IntuneWin32App module installed (Install-Module -Name "IntuneWin32App" -AcceptLicense) 
- Access to the PnP certificate specified in `PNP_CERT_LOCAL`.
- PowerShell execution enabled.
- Administrative rights to install and uninstall software during testing.

---

## Publishing Results

Upon successful completion:

- Win32 application is uploaded to Intune.
- Existing applications are updated automatically.
- New applications are created automatically.
- Required deployment assignment is configured.
- Application is assigned to the group specified in: `AssignmentGroupName`  

---

# Example Contributor Workflow

```powershell
#creat the working branch
git checkout -b add-7zip

# Create these folders and files in the repo:
# apps/7-Zip/app.json
# apps/7-Zip/test-detection.ps1
# Do this manually or via pwsh commands

# Once all changes have been made and files have been added:
git add .
git commit -m "Added 7-Zip package [app:7-Zip]"
git push origin add-7zip
```
(This can also be done via VSCode GUI if Git module is installed. Review SOP for steps)

Then:
1. Open a Pull Request.
2. Obtain reviewer approval.
3. Merge to `main`.
4. Approve the Production deployment when prompted.
5. Verify application deployment in Intune.