$outFilePath = "{0}" -f "$env:USERPROFILE\Downloads"
$bootstrapper = "{0}\teamsbootstrapper.exe" -f $outFilePath

Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2243204" -OutFile $outFilePath\teamsbootstrapper-x64.exe
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2196106" -OutFile $outFilePath\MSTeams-x64.msix
& $bootstrapper -p -o '$env:USERPROFILE\Downloads\MSTeams-x64.msix'
