# Intune App Factory

## Overview

Intune App Factory provides a standardized process for packaging, validating, and deploying Win32 applications to Microsoft Intune.

The repository uses GitHub Actions to automate the complete application lifecycle:

1. Build a Win32 (`.intunewin`) package.
2. Test application installation and detection on a dedicated self-hosted runner.
3. Require manual approval before production deployment.
4. Upload the application to Microsoft Intune.
5. Assign the application to a pre-defined Entra ID / Intune group.

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

## app.json

Each application must contain an `app.json` file.

Example:

```json
{
  "Name": "7-Zip",
  "DisplayName": "7-Zip",
  "Publisher": "7-Zip",
  "Description": "7-Zip is a file archiver with a high compression ratio.",
  "InstallerType": "MSI",
  "SourceUri": "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.msi",
  "SetupFileName": "7z2602-x64.msi",
  "Architecture": "x64",
  "InstallArguments": "/qn /norestart",
  "MinimumSupportedWindowsRelease": "W10_1809",
  "Category": "Productivity",
  "InformationURL": "https://www.7-zip.org",
  "PrivacyURL": "https://www.7-zip.org",
  "AssignmentGroupName": "SG-Intune-App-7-Zip-Pilot",
  "InstallExperience": "system",
  "RestartBehavior": "suppress"
}
```

### Important Fields

| Field | Description |
|---------|-------------|
| DisplayName | Name displayed in Intune |
| SourceUri | Installer download location |
| SetupFileName | Installer filename |
| InstallerType | Currently supports MSI |
| InstallArguments | Silent install arguments |
| AssignmentGroupName | Intune group to receive the application |
| Architecture | x64, x86, etc. |
| MinimumSupportedWindowsRelease | Minimum supported Windows version |

---

## Installer Sources

Two installer source methods are supported.

### Option 1: SharePoint Hosted Installer

Upload the installer to the Intune App Factory SharePoint site.

Use the following value in `app.json`:

```json
"SourceUri": "https://1svh3d.sharepoint.com/sites/Intune-App-Factory"
```

The build process will:

- Authenticate using PnP PowerShell.
- Retrieve the installer from SharePoint.
- Match the file using the `SetupFileName` value.

Example:

```json
{
  "SourceUri": "https://1svh3d.sharepoint.com/sites/Intune-App-Factory",
  "SetupFileName": "7z2602-x64.msi"
}
```

### Option 2: External Download URL

Specify a direct download URL.

Example:

```json
{
  "SourceUri": "https://github.com/ip7z/7zip/releases/download/26.02/7z2602-x64.msi"
}
```

The build process downloads the installer directly from the URL.

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

## Commit Requiremen*s

When adding or modifying an app*ication, the commit message **must** contain:

```text
[app:<AppName>*
```

Example:

```text
Added new *pplication definition [app:7-Zip]
*``

The workflow uses this value t* identify which*application should be built and de*loyed.

---

## Pull Request Proce*s

1.*Push your feature branch.
2. Creat* a Pull Request.
3. Obtain approva* from at least one reviewer.
4. Me*ge into `main`.

A merge to `main`*triggers the deployment workflow.
*---

# Pipeline Stages

## Stage 1*- Build

The workflow:

1. Reads `*pp.json`.
2. Downloads the install*r.
3. Builds a `.intunewin` packag*.
4. Produces artifacts containing*
   - `.intunewin`
   - `app.json`*   - `test-detection.ps1`
   - Ori*inal installer

Output location:

*``text
build/<AppName>/output
```
*---

## Stage 2 - Test

Testing oc*urs on the dedicated self-hosted r*nner.

The test process:

1. Insta*ls the application.
2. Executes `t*st-detection.ps1`.
3. Verifies the*application is detected.
4. Uninst*lls the application.
5. Executes `*est-detection.ps1` again.
6. Verif*es the application is no longer de*ected.

The deployment continues o*ly if all tests pass.

### Current*Limitation

Automated testing curr*ntly supports:

*``*son
"InstallerType": "MSI"
*``

Additional installer types may*require updates to the test framew*rk.

---

## Stage 3 - Production *pproval

After successful testing,*GitHub pauses the workflow at the *roduction environment approval gat*.

Deployment cannot proceed until*an authorized approver approves th* release.

---

## Stage 4 - Publi*h to Intune

The publish process:
*1. Connects to Microsoft Intune.
2* Creates a new Win32 application i* one does not already exist.
3. Up*ates an existing application if fo*nd.
4. Uploads the latest `.intune*in` package.
5. Applies applicatio* metadata.
6. Assigns the applicat*on to the target deployment group *efined in `AssignmentGroupName`.

*eployment assignment type:

```tex*
Required
```

---

# Required Git*ub Secrets

The following GitHub A*tions secrets must be configured.
*| Secret | Purpose |
|----------|-*--------|
| AZURE_CLIENT_ID | Appl*cation registration used for Intun* uploads |
| AZURE_TENANT_ID | Azu*e tenant ID |
| AZURE_CLIENT_SECRE* | Application secret used for Int*ne uploads |
| PNP_CLIENT_ID | PnP*PowerShell application registratio* |
| PNP_CERT_LOCAL | Path to PnP *ertificate (.pfx) on the self-host*d runner |

---

## Self-Hosted Ru*ner Requirements

The build and te*t jobs run on a self-hosted Window* runner with the labels:

```text
*elf-hosted
windows
intune-test
```*
The runner must have:

- Network *ccess to SharePoint (if used).
- A*cess to the PnP certificate specif*ed in `PNP_CERT_LOCAL`.
- PowerShe*l execution enabled.
- Administrat*ve rights to install and uninstall*software during testing.

---

## *ublishing Results

Upon successful*completion:

- Win32 application i* uploaded to Intune.
- Existing ap*lications are updated automaticall*.
- New applications are created a*tomatically.
- Required deployment*assignment is configured.
- Applic*tion is assigned to the group spec*fied in:

```json
"AssignmentGroup*ame"
```

---

## Example Contribu*or Workflow

```powershell
git che*kout -b add-7zip

# Create:
# apps*7-Zip/app.json
# apps/7-Zip/test-d*tection.ps1

git add .
git commit *m "Added 7-Zip package [app:7-Zip]*
git push origin add-7zip
```

The*:

1. Open a Pull Request.
2. Obta*n reviewer approval.
3. Merge to `main`.
4. Approve the Production deployment when prompted.
5. Verify application deployment in Intune.