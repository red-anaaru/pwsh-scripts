<#
.SYNOPSIS
    Installs the containerized version of Microsoft Teams.
.DESCRIPTION
    This script installs the containerized version of Microsoft Teams by uninstalling any existing version and installing a new one from a specified MSIX file.
.PARAMETER msixPath
    The path to the MSIX file for the containerized version of Microsoft Teams.
.EXAMPLE
    .\Install-ContainerizedTeams.ps1 -msixPath "C:\path\to\your\MSIXfile.msix"
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$msixPath
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

# Uninstall existing MSTeams package
$packageName = "MSTeams_8wekyb3d8bbwe"
$package = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue
if ($package) {
  Write-Host "Uninstalling existing MSTeams package..."
  Remove-AppxPackage -Package $package.PackageFullName
} else {
  Write-Host "No existing MSTeams package found."
}

# Install the new MSTeams package
if (Test-Path $msixPath) {
  Write-Host "Installing MSTeams from $msixPath..."
  Add-AppxPackage -Path $msixPath
} else {
  Write-Host "MSIX file not found at $msixPath. Please provide a valid path."
  exit 1
}

$configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -f $env:LOCALAPPDATA
New-Item -Path $configJsonPath -ItemType Directory -Force
$stopUpdateJsonStr = "{'x64/buildLink': '', 'x64/latestVersion': '', 'core/devMenuEnabled': true, 'logging/minimumSeverity': 'DebugPII', 'webview/usePreReleaseWebview2Runtime': false, 'nativeModules/remoteModuleContainerEnabled': true}"
$stopUpdateJsonStr | ConvertFrom-Json | ConvertTo-Json | Out-File -FilePath $configJsonPath\configuration.json
