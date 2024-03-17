Param (
  $cloud,
  $os,
  $ring,
  $appPlat,
  $appVer,
  $tenantId,
  $userId,
  $cpuArch
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

switch ($plat) {
  'tfl' { $platId = $tflPlatId }
  'mac' { $platId = $macPlatId }
  'mtr' { $platId = $mtrPlatId }
  Default {
    $platId = $tfwPlatId
  }
}

$settingAgents = 'TeamsBuilds,TeamsWebview2'

$ecsFetchUrl = 'https://{$ecsUrl}/config/v1/MicrosoftTeams/{$platId}_{appVer}?&agents={$settingAgents}&audience={$ring}&cloud={$cloud}&cpuarch={cpuArch}&desktopVersion={appVer}&environment={cloud}&osplatform={osplat}&osversion={osVer}&teamsring={ring}'

If ($tenantId) {
  $ecsFetchUrl += "&tenantId={$tenantId}"
}

If ($userId) {
  $ecsFetchUrl += "&aaduserid={$userId}"
}

Invoke-WebRequest -Uri $ecsFetchUrl -UseBasicParsing -OutFile $outDir\$cloud-ecs.json
