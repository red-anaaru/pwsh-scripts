param (
  [ValidateSet("TfwDebug", "TfwRelease", "Debug", "Release")]
  [string]$buildConfig = "TfwDebug",

  [ValidateSet("x64", "arm64", "x86")]
  [string]$buildArch = "x64",
  [string]$repoPath = (Get-Location).Path,
  [switch]$skipDepsInstall = $false,
  [switch]$UseCmake = $false
)

# Change to the repository directory
$fullRepoPath = Resolve-Path -Path $repoPath
Set-Location $fullRepoPath

if ($UseCmake) {
  cmake --preset $buildArch-windows
  cmake --build --preset $buildArch-windows
} else {
  if (-not $skipDepsInstall) {
    .\scripts\install-deps.ps1 -Platform $buildArch-windows
  }
  if ($LASTEXITCODE -eq 0 -and $skipDepsInstall) {
    # Get the number of processors and calculate the parallel build count
    $numberOfProcessors = [int]::Parse($env:NUMBER_OF_PROCESSORS)
    $parallelBuildCount = $numberOfProcessors - 4

    # Ensure the parallel build count is at least 1
    if ($parallelBuildCount -lt 4) {
      $parallelBuildCount = 1
    }

    # Start Visual Studio Developer PowerShell for the specified build architecture
    $arch = if ($buildArch -eq "x64") { "amd64" } else { $buildArch }
    # Import Visual Studio Developer PowerShell
    $vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
    $vsDevShell = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    Import-Module $vsDevShell
    Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments """-arch=x64 -host_arch=x64"""
    Write-Host "Starting build for $fullRepoPath (configuration: $buildConfig, architecture: $buildArch)..."
    Write-Host 'Using \$parallelBuildCount parallel build processes'
    msbuild .\src\Teams.sln /p:Configuration=$buildConfig /p:Platform=$buildArch /m:$parallelBuildCount
  } else {
    Write-Host 'Dependency installation failed. Exiting build process.'
    exit 1
  }
}
