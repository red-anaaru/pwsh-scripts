param(
  [switch]$Undo,
  [switch]$useStableWv2,
  [switch]$usePreRelWv2 = $false
)

# Ensure useStableWv2 and usePreRelWv2 are mutually exclusive
if ($useStableWv2 -and $usePreRelWv2) {
  Write-Error "You cannot use both -useStableWv2 and -usePreRelWv2 switches at the same time."
  exit 1
}

if ($Undo) {
  $configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\configuration.json" -f $env:LOCALAPPDATA

  $configJson = Get-Content -Path $configJsonPath -Raw
  if (![string]::IsNullOrEmpty($configJson)) {
    $configObject = $configJson | ConvertFrom-Json
    if ($configObject.PSObject.Properties.Name -contains 'x64/buildLink') {
      $configObject.PSObject.Properties.Remove('x64/buildLink')
    }
    if ($configObject.PSObject.Properties.Name -contains 'x64/latestVersion') {
      $configObject.PSObject.Properties.Remove('x64/latestVersion')
    }
    $configJson = $configObject | ConvertTo-Json
    $configJson | Out-File -FilePath $configJsonPath
    Write-Host "Removed 'x64/buildLink' and 'x64/latestVersion' from configuration.json"
  }
  else {
    Write-Host "configuration.json is empty"
  }
}
else {
  $configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -f $env:LOCALAPPDATA
  New-Item -Path $configJsonPath -ItemType Directory -Force
  $stopUpdateJsonStr = "{'x64/buildLink': '', 'x64/latestVersion': '', 'core/devMenuEnabled': true, 'logging/minimumSeverity': 'DebugPII'}"
  $configObject = $stopUpdateJsonStr | ConvertFrom-Json

  if ($usePreRelWv2) {
    $configObject.'webview/usePreReleaseWebview2Runtime' = $true
  } else {
    $configObject.'webview/usePreReleaseWebview2Runtime' = $false
  }

  if ($useStableWv2 -and $configObject.'webview/usePreReleaseWebview2Runtime' -eq $true) {
    $configObject.'webview/usePreReleaseWebview2Runtime' = $false
  }

  $configJson = $configObject | ConvertTo-Json
  $configJson | Out-File -FilePath $configJsonPath\configuration.json
}
