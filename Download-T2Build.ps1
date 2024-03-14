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
  [Switch] $dryRun = $false)

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