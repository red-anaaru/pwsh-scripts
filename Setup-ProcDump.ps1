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

Start-Process powershell -Verb runAs -ArgumentList '-Command & {procdump -ma -i $dumpCollectionPath -accepteula}'
