<#
.SYNOPSIS
Download-T2Build.ps1 will download a specific build of new Teams client from the Teams CDN.
You can also install the downloaded build on Windows by using the -Install switch.

.DESCRIPTION
Download-T2Build.ps1 will download a specific build of new Teams client from the Teams CDN
for the specified ring and architecture. You can also install the downloaded build on Windows 
by using the -Install switch. The script will download the build to the Downloads folder.
You can use the -dryRun switch to see the download command without actually downloading the build.

.PARAMETER build
The desktop client version to download.

.PARAMETER platform
The platform to download the build for. Valid values are "windows" and "osx".

.PARAMETER ring
The ring to download the build for. Valid values are "r0", "r1", "r2", "r3", and "r4".
If not specified, the default value is "r0".

.PARAMETER arch
The architecture to download the build for. Valid values are "x64", "arm64", and "x86".
If not specified, the default value is "x64".

.PARAMETER dryRun
Show the download command without actually downloading the build.

.PARAMETER Install
If specified, it installs the downloaded build on Windows.

.EXAMPLE
To download a specific build of the Teams client from a specific ring:
Download-T2Build.ps1 -build 12345.6000.0789.1234 -ring r4

.EXAMPLE
To download and install a specific build of the Teams client from a specific ring:
Download-T2Build.ps1 -build 12345.6000.0789.1234 -ring r4 -Install

.EXAMPLE
To download and do a dry run of a specific build of the Teams client from a specific ring:
Download-T2Build.ps1 -build 12345.6000.0789.1234 -ring r4 -dryRun

.NOTES
Any additional notes about the script.
#>

Param(
  [Parameter(mandatory=$true)]
  [string] $build,
  [Parameter()]
  [ValidateSet("windows","osx")]
  [string] $platform = "windows",
  [Parameter()]
  [ValidateSet("r0","r1","r2","r3","r4")]
  [string] $ring = "r0",
  [Parameter()]
  [ValidateSet("x64","arm64","x86")]
  [string] $arch = "x64",
  [Switch] $dryRun = $false,
  [Switch] $Install = $false)

if ($build -eq $nul) {
  Write-Output "Usage: Download-T2ClientBuild.ps1 -build 12345.6000.0789.1234 -ring r3"
  Exit
}

$statics = If ($ring -ne "r4") {"staticsint"} Else {"statics"}
$appName = If ($platform -eq "windows") {"MSTeams"} Else {"MicrosoftTeams"}
$extn = If ($platform -eq "windows") {"msix"} Else {"pkg"}
$appPkgName = "{0}-{1}.{2}" -f $appName, $arch, $extn
$buildUrl = "https://{0}.teams.cdn.office.net/production-{1}-{2}/{3}/{4}" -f $statics, $platform, $arch, $build, $appPkgName
# $homeEnvVar = If ($IsWindows) {"USERPROFILE"} Else {"Home"}

if ($dryRun) {
  Write-Output "Download URL: $buildUrl"
  Exit
}

Write-Information "Downloading..."
# $downloadPath = Join-Path -Path [Environment]::GetEnvironmentVariable($homeEnvVar) -ChildPath "Downloads"
$downloadPath = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
$pkgFile = Join-Path -Path $downloadPath -ChildPath $appPkgName
Invoke-WebRequest -Uri $buildUrl -OutFile $pkgFile
Write-Output "Downloaded $pkgFile"

if ($Install) {
  Write-Information "Checking existing Teams installation..."
  $teamsApp = Get-AppxPackage -Name "MSTeams"
  if ($teamsApp) {
    Write-Information "Uninstalling $teamsApp.PackageFullName ..."
    Remove-AppxPackage -Package $teamsApp.PackageFullName
  }
  Write-Information "Installing $pkgFile..."
  if ($platform -eq "windows") {
    Add-AppxPackage -Path $pkgFile
  } else {
    Write-Error "Installation is not supported on this platform."
  }
}
