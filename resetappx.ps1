#Reset-AppxPackage has possibility of stalling. If timeout is longer than 15 secs, application will be cleaned up instead
param([String] $appName)

$scriptBlock = {
  param([String] $appName)

  try {
    Get-AppxPackage $appName | Reset-AppxPackage
    Start-Sleep -s 1
  } catch {
    throw $_
  }
}

$job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $appName
$job | Wait-Job -Timeout 5 | Out-Null 
$job | Stop-Job | Out-Null

if($job.State -eq 'Stopped') {
  throw "Reset command timed out."
}
elseif ($job.State -eq 'Failed') {
  $err = $job.ChildJobs[0].JobStateInfo.Reason.Message
  throw $err
}