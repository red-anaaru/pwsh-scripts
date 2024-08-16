Invoke-WebRequest -Uri "https://aka.ms/windbg/download" -OutFile "$env:USERPROFILE\Downloads\windbg.appinstaller"
If (Test-Path "$env:USERPROFILE\Downloads\windbg.appinstaller") {
  Add-AppxPackage -AppInstaller "$env:USERPROFILE\Downloads\windbg.appinstaller"
  Remove-Item "$env:USERPROFILE\Downloads\windbg.appinstaller"
} Else {
  Write-Host "WinDbg.appinstaller not found in Downloads folder."
}
