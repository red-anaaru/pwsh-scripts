<#
.SYNOPSIS
Downloads and installs a specified Sysinternals tool.

.DESCRIPTION
This script downloads and installs a specified Sysinternals tool or the entire tool suite.

.PARAMETER tool
The key of the tool to be downloaded and installed. Valid keys are: procmon, handle, procexp, sysmon, all.

.EXAMPLE
.\Setup-Sysinternals.ps1 -tool procmon
Downloads and installs Process Monitor.

.EXAMPLE
.\Setup-Sysinternals.ps1 -tool all
Downloads and installs Sysinternals Suite.

#>

param (
  [Parameter(Mandatory=$true)]
  [ValidateSet("procmon", "handle", "procexp", "sysmon", "all")]
  [string]$tool,

  [string]$installPath = "$env:USERPROFILE\Tools"
)

# Map
$toolsMap = @{
    "procmon" = "ProcessMonitor"
    "handle" = "Handle"
    "procexp" = "ProcessExplorer"
    "sysmon" = "Sysmon"
    "all" = "SysinternalsSuite"
}

function DownloadAndInstall {
  param (
    [string]$toolName,
    [string]$destinationPath
  )

    $downloadUrl = "https://download.sysinternals.com/files/$toolName.zip"
    $downloadPath = "$env:USERPROFILE\Downloads\$toolName.zip"

    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
    If (Test-Path $downloadPath) {
        $finalExtractPath = Join-Path -Path $destinationPath -ChildPath "SysinternalsTools"
  
        if (-not (Test-Path $finalExtractPath)) {
        New-Item -ItemType Directory -Path $finalExtractPath | Out-Null
        }
  
        Expand-Archive -Path $downloadPath -DestinationPath $finalExtractPath

        Write-Host "Add SysinternalsTools to PATH"
        $CurrentPath = [Environment]::GetEnvironmentVariable('PATH')
        $CurrentPath = $CurrentPath + ';' + "$finalExtractPath" + ';'
        [Environment]::SetEnvironmentVariable('PATH', $CurrentPath, "User")

        Write-Host "Cleaning up..."
        Remove-Item $downloadPath
    } else {
        Write-Host "Failed to download $toolName"
    }
}

DownloadAndInstall -toolName $toolsMap[$tool] -destinationPath $installPath
