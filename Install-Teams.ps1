<#
.SYNOPSIS
    Installs the specified Microsoft Teams MSIX package.
.DESCRIPTION
    This script uninstalls existing version of Teams and installs the specified MSIX file.
.PARAMETER msixPath
    The path to the MSIX file to be installed.
.EXAMPLE
    .\Install-Teams.ps1 -msixPath "C:\path\to\your\MSIXfile.msix"
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$msixPath,
  [switch]$SkipCertInstall
)

# Prompt for msixPath if not provided
if (-not $msixPath) {
  $msixPath = Read-Host "Please provide the path to the MSIX file"
}

# Expand environment variables in the path
$expandedMsixPath = [System.Environment]::ExpandEnvironmentVariables($msixPath)

# Validate the path
if (-not (Test-Path $expandedMsixPath)) {
  Write-Host "Invalid path provided. The path does not exist. Please provide a valid path to the MSIX file."
  exit 1
}

if (-not $expandedMsixPath.ToLower().EndsWith('.msix')) {
  Write-Host "Invalid file type. The path does not point to an MSIX file. Please provide a valid path to the MSIX file."
  exit 1
}

function Add-SignerCertificateToStore {
  param (
    [Parameter(Mandatory = $true)]
    [string]$msixPath,
    [Parameter(Mandatory = $true)]
    [string]$certStore
  )

  # Get the Authenticode signature of the specified msix file
  $sig = Get-AuthenticodeSignature -FilePath $expandedMsixPath

  # Open the specified certificate store
  $store = Get-Item $certStore
  $store.Open('ReadWrite')

  # Add the SignerCertificate to the certificate store
  $store.Add($sig.SignerCertificate)

  # Close the certificate store
  $store.Close()
}

if ($SkipCertInstall) {
  Write-Host "Skipping certificate installation."
} else {
  Write-Host "Installing signer certificate to the store..."

  # Call the function to add the signer certificate to the store
  Add-SignerCertificateToStore -msixPath $expandedMsixPath -certStore "Cert:\LocalMachine\Root"
}

# Uninstall existing MSTeams package
$package = Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue
if ($package) {
  Write-Host "Uninstalling existing MSTeams package..."
  Remove-AppxPackage -Package $package.PackageFullName
} else {
  Write-Host "No existing MSTeams package found."
}

# Install the new MSTeams package
Write-Host "Installing MSTeams from $expandedMsixPath..."
try {
  Add-AppxPackage -Path $expandedMsixPath
} catch {
  Write-Host "Failed to install MSTeams. Exception: $_"
  exit 1
}

Write-Host "MSTeams installed successfully."

# Create the configuration.json file to stop auto-updates
$configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -f $env:LOCALAPPDATA
New-Item -Path $configJsonPath -ItemType Directory -Force
$jsonStr = @"
{
    "x64/buildLink": "",
    "x64/latestVersion": "",
    "core/devMenuEnabled": true,
    "logging/minimumSeverity": "DebugPII",
    "nativeModules/oopSlimcore": true,
    "nativeModules/oopSlimcoreMode": "all",
    "nativeModules/remoteModuleAppContainerEnabled": true,
    "webview/usePreReleaseWebview2Runtime": false
}
"@
$jsonStr | ConvertFrom-Json | ConvertTo-Json | Out-File -FilePath $configJsonPath\configuration.json
