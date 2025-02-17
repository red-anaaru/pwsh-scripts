<#
.SYNOPSIS
    Builds the Teams Client Native Shell (TCNS) project with specified configuration and architecture.

.DESCRIPTION
    This script handles the build process for the TCNS project, supporting both CMake and MSBuild paths.
    It can handle different build configurations and architectures, with options to skip dependency
    installation and choose between build systems.

    The script automatically:
    - Configures parallel build based on available CPU cores
    - Sets up Visual Studio Developer environment
    - Handles dependency installation
    - Supports both CMake and MSBuild build systems

.PARAMETER buildConfig
    The build configuration to use.
    Valid values: "TfwDebug", "TfwRelease", "Debug", "Release"
    Default: "TfwDebug"

.PARAMETER buildArch
    The target architecture for the build.
    Valid values: "x64", "arm64", "x86"
    Default: "x64"

.PARAMETER repoPath
    The path to the TCNS repository.
    Default: Current directory

.PARAMETER skipDepsInstall
    Skip the dependency installation step.
    Default: False

.PARAMETER UseCmake
    Use CMake build system instead of MSBuild.
    Default: False

.EXAMPLE
    # Build using default settings (TfwDebug, x64)
    .\Build-Tcns.ps1

.EXAMPLE
    # Build Release configuration for arm64
    .\Build-Tcns.ps1 -buildConfig Release -buildArch arm64

.EXAMPLE
    # Build using CMake
    .\Build-Tcns.ps1 -UseCmake

.EXAMPLE
    # Build with custom repository path and skip dependency installation
    .\Build-Tcns.ps1 -repoPath "D:\repos\tcns" -skipDepsInstall

.NOTES
    Requirements:
    - Visual Studio 2022 with C++ workload
    - CMake (if using -UseCmake)
    - PowerShell 5.1 or higher
    - Administrator privileges may be required for dependency installation
#>

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
  if ($buildConfig -eq "TfwDebug" -or $buildConfig -eq "Debug") {
    $buildConfig = "Debug"
  } else {
    $buildConfig = "RelWithDebInfo"
  }
  cmake --preset $buildArch-windows
  cmake --build --preset $buildArch-windows --config=$buildConfig
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
