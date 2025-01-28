$domorexpVstsBuildApi = "https://domoreexp.visualstudio.com/Teamspace/_apis/build/builds/"
$domorexpVstsReleaseApi = "https://domoreexp.vsrm.visualstudio.com/Teamspace/_apis/Release/"
$teamspacewebVstsRepoUri = "https://domoreexp.visualstudio.com/Teamspace/_apis/git/repositories/Teamspace-Web"
if (-not $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI) {
    $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = "https://domoreexp.visualstudio.com/"
}
if (-not $env:SYSTEM_TEAMPROJECTID) {
    $env:SYSTEM_TEAMPROJECTID = "11ac29bc-5a99-400b-b225-01839ab0c9df"
}

Import-Module D:\cifx-tests\trigger\vsts.psm1 -Force
Import-Module D:\cifx-tests\trigger\utils.psm1 -Force
Import-Module D:\cifx-tests\trigger\config\Config.psm1 -Force
Initialize-VstsModule -Pat $env:vstsPat -UseSystemAccessToken:$UseSystemAccessToken -BuildRepositoryName teams-client-native-shell

$url = "$domorexpVstsBuildApi/14568369/artifacts?api-version=4.1"
$url

$artifact = Invoke-VstsRestMethod -Uri $url
$artifact
$architecture = "x64"
($artifact.value | Where-Object { $_.name -eq "windows x64" } |Select-Object -ExpandProperty resource | Select-Object -ExpandProperty data) -match "(\d+)"
$container = $matches[0]
$url2 = "https://domoreexp.visualstudio.com/_apis/resources/Containers/$container/windows%20x64?itemPath=windows%20x64"
$all_artifacts = Invoke-VstsRestMethod -Uri $url2
$msix = $all_artifacts.value | where-object {$_.contentLocation.contains("MSTeams-")}
$msix.contentLocation

# $all_artifacts | Where-Object {$_.path -eq $teams}

#$artifactName = "MSTeams"
#$edgeMaglevArtifact = "https://domoreexp.visualstudio.com/_apis/resources/Containers/$container/windows%20$($architecture)?itemPath=windows%20$architecture%2F$artifactName-$architecture.msix"
#$edgeMaglevArtifact