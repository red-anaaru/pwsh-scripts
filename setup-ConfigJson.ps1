#!/usr/bin/env pwsh
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String] $Key,
    [Parameter(Mandatory=$true)]
    [String] $Value
)
function Test-IsBoolean {
  param (
    [Parameter(Mandatory=$true)]
    [String] $inputString
  )

  try {
    [bool]::Parse($inputString) | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

function Test-IsInteger {
  param (
    [Parameter(Mandatory=$true)]
    [String] $inputString
  )

  try {
    [int]::Parse($inputString) | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

$configJsonPath = "{0}\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -f $env:LocalAppData
New-Item -Path $configJsonPath -ItemType Directory -Force

If (!(Test-Path -Path $configJsonPath\configuration.json)) {
    New-Item -Path $configJsonPath\configuration.json -ItemType File -Force
    @{} | ConvertTo-Json | Out-File -FilePath $configJsonPath\configuration.json
}

$configJsonObj = Get-Content -Path $configJsonPath\configuration.json | ConvertFrom-Json

If (Test-IsBoolean $Value) {
  $Value = [bool]::Parse($Value)
  $configJsonObj | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
} ElseIf (Test-IsInteger $Value) {
  $Value = [int]::Parse($Value)
  $configJsonObj | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force
} else {
  Write-Error "Value is not a boolean or an integer"
}

$configJsonObj | ConvertTo-Json | Out-File -FilePath $configJsonPath\configuration.json

