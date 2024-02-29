$configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -f $env:LOCALAPPDATA
New-Item -Path $configJsonPath -ItemType Directory -Force
$stopUpdateJsonStr = "{'x64/buildLink': '', 'x64/latestVersion': ''}"
$stopUpdateJsonStr | ConvertFrom-Json | ConvertTo-Json | Out-File -FilePath $configJsonPath\configuration.json