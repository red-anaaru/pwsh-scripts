<#
.SYNOPSIS
    Automated setup script for Teams Client Native Shell (TCNS) development environment.

.DESCRIPTION
    This script automates the installation and configuration of all necessary tools and dependencies
    for Teams Client Native Shell development. It runs in two steps:
    
    Step 1:
    - Installs Visual Studio 2022 Enterprise
    - Installs Git
    - Installs NVM for Windows
    - Installs Azure CLI
    - Installs LLVM
    - Installs CMake
    - Installs NuGet
    - Installs WinDbg and Sysinternals (optional)

    Step 2:
    - Configures Azure DevOps CLI
    - Installs Node.js and sets up specific version
    - Installs Yarn
    - Clones the TCNS repository
    - Configures Visual Studio with required components

.PARAMETER teamsReposDir
    The directory where the Teams repositories will be cloned. Default is "C:\teams-repos"

.PARAMETER repoDir
    The directory name for the TCNS repository. Default is "tcns"

.PARAMETER InstallStep
    Specifies which installation step to run. Valid values are "Step1" or "Step2". Default is "Step1"

.PARAMETER SkipVSInstall
    Skip Visual Studio 2022 Enterprise installation

.PARAMETER SkipGitInstall
    Skip Git installation

.PARAMETER SkipDebugToolsInstall
    Skip installation of debugging tools (WinDbg and Sysinternals)

.EXAMPLE
    # Run the complete installation with default settings
    .\Setup-Tcns.ps1

.EXAMPLE
    # Run installation with custom repository directory
    # Repository will be cloned to "D:\repos\my-tcns"
    .\Setup-Tcns.ps1 -teamsReposDir "D:\repos" -repoDir "my-tcns"

.EXAMPLE
    # Skip Visual Studio and Git installation
    .\Setup-Tcns.ps1 -SkipVSInstall -SkipGitInstall

.EXAMPLE
    # Run only Step2 of the installation
    .\Setup-Tcns.ps1 -InstallStep Step2

.NOTES
    - Requires Windows 10/11
    - Must be run with administrator privileges
    - Internet connection required
    - Visual Studio 2022 installation requires significant disk space
#>

param(
    [string]$teamsReposDir = "C:\teams-repos",
    [string]$repoDir = "tcns",
    [string]$InstallStep = "Step1",
    [Switch]$SkipVSInstall,
    [Switch]$SkipGitInstall,
    [Switch]$SkipDebugToolsInstall
)

# Check if the current shell is running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Output "Current shell is not running as Administrator. Restarting with elevated privileges..."
  if ($InstallStep -eq "Step1") {
    Start-Process pwsh -ArgumentList "-File `"$MyInvocation.MyCommand.Path`" -InstallStep Step1" -Verb RunAs
    exit
  }
} else {
  Write-Output "Current shell is already running as Administrator."
}

if ($InstallStep -eq "Step1") {
  if (-not $SkipVSInstall) {
    Write-Output "Installing Visual Studio 2022 Enterprise..................................."
    winget install --id Microsoft.VisualStudio.2022.Enterprise --source winget --silent --accept-package-agreements --accept-source-agreements
  }

  if (-not $SkipGitInstall) {
    Write-Output "Installing Git..................................."
    winget install --id Microsoft.Git --source winget --silent --accept-package-agreements --accept-source-agreements
  }

  Write-Output "Installing NVM for Windows..................................."
  winget install --id CoreyButler.NVMforWindows --source winget --silent --accept-package-agreements --accept-source-agreements

  Write-Output "Installing Azure CLI..................................."
  winget install --id Microsoft.AzureCLI --source winget --silent --accept-package-agreements --accept-source-agreements

  Write-Output "Installing LLVM..................................."
  winget install --id LLVM.LLVM --Version 18.1.8 --silent --accept-package-agreements --accept-source-agreements

  Write-Output "Installing CMake ..................................."
  winget install --id Kitware.CMake --source winget --silent --accept-package-agreements --accept-source-agreements

  Write-Output "Installing Nuget ..................................."
  winget install --id NuGet.NuGet --source winget --silent --accept-package-agreements --accept-source-agreements

  if (-not $SkipDebugToolsInstall) {
    Write-Output "Installing Windbg ..................................."
    winget install --id Microsoft.WinDbg --source winget --silent --accept-package-agreements --accept-source-agreements

    Write-Output "Installing Sysinternals suite ..................................."
    winget install --id Microsoft.Sysinternals --source winget --silent --accept-package-agreements --accept-source-agreements
  }

  Write-Output "Restarting PowerShell in Admin mode and continue setup ..................................."
  Write-Output $MyInvocation.MyCommand.Path
  Start-Process pwsh -ArgumentList "-File `"$MyInvocation.MyCommand.Path`" -InstallStep Step2" -Verb RunAs
  exit
}
elseif ($InstallStep -eq "Step2") {
  Write-Output "Installing Azure DevOps CLI extension..................................."
  az extension add --name azure-devops
  az devops configure --defaults organization=https://dev.azure.com/domoreexp project=Teamspace

  Write-Output "Installing Node.js ..................................."
  $NodeVersion = 'v20.12.0'
  nvm install $NodeVersion
  nvm use $NodeVersion

  Write-Output "Installing Yarn ..................................."
  npm install yarn --global

  if (-not (Test-Path -Path $teamsReposDir)) {
    New-Item -ItemType Directory -Path $teamsReposDir -Force | Out-Null
  }

  Set-Location $teamsReposDir
  Write-Output "Cloning teams-client-native-shell repository ..................................."
  $counter = 2
  $newRepoDir = $repoDir
  while (Test-Path -Path "$teamsReposDir\$newRepoDir") {
    $newRepoDir = "$repoDir$counter"
    $counter++
  }
  $repoDir = $newRepoDir
  Write-Output "Cloning teams-client-native-shell to: $teamsReposDir\$repoDir"
  git clone https://domoreexp@dev.azure.com/domoreexp/Teamspace/_git/teams-client-native-shell $repoDir
  git checkout user/anaaru/vsconfig

  Set-Location "C:\Program Files (x86)\Microsoft Visual Studio\Installer"
  .\vs_installer.exe modify `
    --installPath "C:\Program Files\Microsoft Visual Studio\2022\Enterprise" `
    --config c:\teams-repos\tcns\.vsconfig `
    --channelId VisualStudio.17.Release `
    --productID Microsoft.VisualStudio.Product.Enterprise `
    --locale en-US `
    --removeOos true `
    --quiet `
    --norestart `
    --nocache `
    --includeRecommended `
    --includeOptional `
    --force

  Set-Location "$teamsReposDir\$repoDir"

  Write-Output "Setup complete. Please restart your computer to finalize the installation."
  Write-Output "After restart, run the following command to build the project:"
  Write-Output "Press any key to restart your computer now, or press 'q' to quit and restart later."
  $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
  if ($key.Character -ne 'q') {
    Restart-Computer
  } else {
    Write-Output "You chose to restart later. Please remember to restart your computer to finalize the installation."
  }
  exit
}
