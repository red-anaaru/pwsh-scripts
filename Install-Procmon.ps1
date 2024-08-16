Invoke-WebRequest -Uri "https://download.sysinternals.com/files/ProcessMonitor.zip" -OutFile "$env:USERPROFILE\Downloads\ProcessMonitor.zip"
If (Test-Path "$env:USERPROFILE\Downloads\ProcessMonitor.zip") {
  Expand-Archive -Path "$env:USERPROFILE\Downloads\ProcessMonitor.zip" -DestinationPath "$env:USERPROFILE\Tools\ProcessMonitor"
  Remove-Item "$env:USERPROFILE\Downloads\ProcessMonitor.zip"
} else {
  Write-Host "Failed to download Process Monitor"
}