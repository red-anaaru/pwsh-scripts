Param (
  $cloud,
  $os,
  $ring,
  $appPlat,
  $appVer,
  $tenantId,
  $userId,
  $cpuArch,
  $outDir
)

$prodEcsBaseUrl = "https://config.teams.microsoft.com/config/v1/";
$ag08EcsBaseUrl = "https://config.ecs.teams.eaglex.ic.gov/config/v1/"
$ag09EcsBaseUrl = "https://config.ecs.teams.microsoft.scloud/config/v1/"
$dodEcsBaseUrl = "https://config.ecs.dod.teams.microsoft.us/config/v1/"
$gallatinEcsBaseUrl = "https://mooncake.config.teams.microsoft.com/config/v1/"
$gcchEcsBaseUrl = "https://config.ecs.gov.teams.microsoft.us/config/v1/"

$tflPlatId = 48
$tfwPlatId = 49
$macPlatId = 50
$mtrPlatId = 51

$clientName = "MicrosoftTeams"

switch ($cloud) {
  'ag08' {
    $ecsUrl = $ag08EcsBaseUrl
  }
  'ag09' {
    $ecsUrl = $ag09EcsBaseUrl
  }
  'dod' {
    $ecsUrl = $dodEcsBaseUrl
  }
  'gallatin' {
    $ecsUrl = $gallatinEcsBaseUrl
  }
  'gcchigh' {
    $ecsUrl = $gcchEcsBaseUrl
  }
  Default {
    $ecsUrl = $prodEcsBaseUrl
  }
}

switch ($appPlat) {
  'tfl' { $platId = $tflPlatId }
  'mac' { $platId = $macPlatId }
  'mtr' { $platId = $mtrPlatId }
  Default {
    $platId = $tfwPlatId
  }
}

$settingAgents = 'TeamsBuilds,TeamsWebview2'

$ecsFetchUrl = 'https://{0}/config/v1/MicrosoftTeams/{1}_{2}?&agents={3}&audience={4}&cloud={5}&cpuarch={6}&desktopVersion={2}&environment={5}&osplatform={7}&osversion={8}&teamsring={4}' -f $ecsUrl, $platId, $appVer, $settingAgents, $ring, $cloud, $cpuArch, $osplat, $osVer

If ($tenantId) {
  $ecsFetchUrl += "&tenantId={$tenantId}"
}

If ($userId) {
  $ecsFetchUrl += "&aaduserid={$userId}"
}

If ($outDir -eq $null) {
  $outDir = Join-Path -Path $env:USERPROFILE -ChildPath Downloads
}

$ecsJsonPath = Join-Path -Path $outDir -ChildPath "$cloud"-ecs.json

Invoke-WebRequest -Uri $ecsFetchUrl -UseBasicParsing -OutFile $ecsJsonPath
