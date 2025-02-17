param(
    [string]$teamsReposDir = "C:\teams-repos",
    [string]$repoDir = "tcns",
    [string]$InstallStep = "Step1"
)

# Check if the current shell is running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Output "Current shell is not running as Administrator. Restarting with elevated privileges..."
  Start-Process powershell.exe "-File `"$PSCommandPath`" -ArgumentList `"-InstallStep Step1`"" -Verb RunAs
  exit
}
else {
  Write-Output "Current shell is already running as Administrator."
}

if ($InstallStep -eq "Step1") {
  Write-Output "Installing Visual Studio 2022 Enterprise..."
  winget install --id Microsoft.VisualStudio.2022.Enterprise --source winget

  Write-Output "Installing Git..."
  winget install --id Microsoft.Git --source winget

  Write-Output "Installing NVM for Windows..."
  winget install --id CoreyButler.NVMforWindows --source winget

  Write-Output "Installing Azure CLI..."
  winget install --id Microsoft.AzureCLI --source winget

  Write-Output "Installing LLVM..."
  winget install --id LLVM.LLVM --Version 18.1.8

  Write-Output "Installing CMake..."
  winget install --id Kitware.CMake --source winget

  Write-Output "Restarting PowerShell in Admin mode and continue setup ..."
  Start-Process powershell.exe "-File `"$PSCommandPath`" -ArgumentList `"-InstallStep Step2`"" -Verb RunAs
  exit
}
elseif ($InstallStep -eq "Step2") {
  Write-Output "Installing Azure DevOps CLI extension..."
  az extension add --name azure-devops
  az devops configure --defaults organization=https://dev.azure.com/domoreexp project=Teamspace

  Write-Output "Installing Node.js..."
  $NodeVersion = 'v20.12.0'
  nvm install $NodeVersion
  nvm use $NodeVersion

  Write-Output "Installing Yarn..."
  npm install yarn --global

  if (-not (Test-Path -Path $teamsReposDir)) {
    New-Item -ItemType Directory -Path $teamsReposDir -Force | Out-Null
  }

  Set-Location $teamsReposDir
  Write-Output "Cloning teams-client-native-shell repository..."
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
  .\vs_enterprise.exe --lang en-US --config $repoDir\vsconfig.json --passive --norestart

  Set-Location "$teamsReposDir\$repoDir"

  Write-Output "Setup complete. Please restart your computer to finalize the installation."
  Write-Output "After restart, run the following command to build the project:"
  Write-Output ""
  exit
}
