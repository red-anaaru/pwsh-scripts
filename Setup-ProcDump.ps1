#!/usr/bin/env pwsh

Param(
  [string] $installPath = "C:\tools",
  [string] $dumpCollectionPath = "C:\dumps"
)
$procdumpPath = (Get-Command procdump.exe).Path

if ([string]::IsNullOrEmpty($procdumpPath)) {
  $downloadedFilePath = Join-Path -Path [Environment]::GetFolderPath('UserProfile') -ChildPath "ProcDump.zip"
  Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Procdump.zip" -OutFile $downloadedFilePath
  $installPath = Join-Path -Path $installPath -ChildPath "ProcDump"
  Expand-Archive -Path $downloadedFilePath -DestinationPath $installPath
  $CurrentPath = [Environment]::GetEnvironmentVariable('PATH')
  $CurrentPath = $CurrentPath + ';' + "$installPath\Procdump" + ';'
  [Environment]::SetEnvironmentVariable('PATH', $CurrentPath, "User")
}

If (Test-Path -Path $dumpCollectionPath -PathType Container) {
  Write-Host "$dumpCollectionPath exists!"
} else {
  New-Item -ItemType Directory -Path $dumpCollectionPath -Force
}

# Test if HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug /v Debugger is set to procdump
procdump -ma -i c:\dumps -accepteula
