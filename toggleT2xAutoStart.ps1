$app = (Get-AppxPackage | Where-Object -Property Name -EQ -Value MSTeams)
$pkgName = $app.PackageFamilyName
$startupTask = ($app | Get-AppxPackageManifest).Package.Applications.Application.Extensions.Extension | Where-Object -Property Category -Eq -Value windows.startupTask
$taskId = $startupTask.StartupTask.TaskId
$state = (Get-ItemProperty -Path "HKCU:Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$pkgName\$taskId" -Name State).State
$regKey = "HKCU:Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$pkgName\$taskId"
if ($state -in 0,1,3) {
    Set-ItemProperty -Path $regKey -Name UserEnabledStartupOnce -Value 1
    Set-ItemProperty -Path $regKey -Name State -Value 2
} else {
    $lastDisabled = [int](New-TimeSpan -Start (Get-Date '1970-01-01 00:00:00 GMT') -End (Get-Date)).TotalSeconds
    Set-ItemProperty -Path $regKey -Name LastDisabledTime -Value $lastDisabled
    Set-ItemProperty -Path $regKey -Name State -Value 1
}
