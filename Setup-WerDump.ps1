Param ($dumpFolder)

If (-Not $dumpFolder) {
    $dumpFolder = $env:LOCALAPPDATA + "\CrashDumps"
}

$teamsapps = @('teams.exe','Update.exe','msteams.exe','msteamsupdate.exe','msteams_canary.exe','msteamsupdate_canary.exe')

foreach ($app in $teamsapps) {
  $registryPath = "HKLM:\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps"
  $registryPath = Join-Path -Path $registryPath -ChildPath $app
  if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
  }
  New-ItemProperty -Path $registryPath -Name DumpFolder -Value $dumpFolder -PropertyType ExpandString -Force
  New-ItemProperty -Path $registryPath -Name DumpCount -Value 20 -PropertyType DWord -Force
  New-ItemProperty -Path $registryPath -Name DumpType -Value 2 -PropertyType DWord -Force
}
