#
# GetDeploymentLogs-Desktop.ps1 is a PowerShell script designed to collect
# various logs and system information to diagnose App deployment problems. 
# To run this script from Explorer, right-click on its icon and choose "Run with PowerShell".
#
# All command line parameters are reserved for use internally by the script.
# Users should launch this script from Explorer.
#

param(
    [switch]$Force = $false,
    [switch]$EnableTracing = $false
    )

function PrintMessageAndExit($ErrorMessage, $ReturnCode)
{
    Write-Host $ErrorMessage
    if (!$Force)
    {
        Pause
    }
    exit $ReturnCode
}

$ScriptPath = $null
try
{
    $ScriptPath = (Get-Variable MyInvocation).Value.MyCommand.Path
    $ScriptDir = Split-Path -Parent $ScriptPath
}
catch {}

# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
  
# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
  
 # Check to see if we are currently running "as Administrator"
 if ($myWindowsPrincipal.IsInRole($adminRole))
 {
    # We are running "as Administrator" - so change the title and background color to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
    clear-host
 }
 else
 {
    # We are not running "as Administrator" - so relaunch as administrator
    
    # Create a new process object that starts PowerShell
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
    
    # Specify the current script path and name as a parameter
    $newProcess.Arguments = $myInvocation.MyCommand.Definition + ' -ExecutionPolicy Unrestricted'
    
    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";
    
    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess) > $null;
    
    # Exit from the current, unelevated, process
    exit
 }
  
$LogsFolderName = 'AppxLogs' + (get-date -uformat %s)
$LogsDestinationPath = $env:TEMP + '\' + $LogsFolderName
$CabPath = $LogsDestinationPath + '.zip'

$SystemEventLogsPath = $env:windir + '\System32\winevt\Logs\'
$WULogsPath = $env:windir + '\Logs\windowsupdate\'
$UpgradeLogs = $env:windir + '\Panther\'

$SystemEventLogFileList = 
    @(
        "Microsoft-Windows-AppXDeployment%4Operational.evtx",
        "Microsoft-Windows-AppXDeploymentServer%4Operational.evtx",
        "Microsoft-Windows-AppxPackaging%4Operational.evtx",
        "Microsoft-Windows-StateRepository%4Operational.evtx",
        "Microsoft-Windows-AppReadiness%4Admin.evtx",
        "Microsoft-Windows-AppReadiness%4Operational.evtx",
        "Microsoft-Windows-TWinUI%4Operational.evtx",
        "Microsoft-Windows-AppModel-Runtime%4Admin.evtx",
        "Microsoft-Windows-AppHost%4Admin.evtx",
        "Microsoft-Windows-ApplicationResourceManagementSystem%4Operational.evtx",
        "Microsoft-Windows-CoreApplication%4Operational.evtx",
        "Microsoft-Windows-AppID%4Operational.evtx",

        "Microsoft-Windows-CodeIntegrity%4Operational.evtx",
        "Microsoft-Windows-Kernel-StoreMgr%4Operational.evtx",
        "Microsoft-Windows-Store%4Operational.evtx",
        "Microsoft-Client-Licensing-Platform%4Admin.evtx",
        "Microsoft-WS-Licensing%4Admin.evtx",

        "Microsoft-Windows-PackageStateRoaming%4Operational.evtx",
        "Microsoft-Windows-DeviceSync%4Operational.evtx",
        "Microsoft-Windows-SettingSync%4Debug.evtx",
        "Microsoft-Windows-SettingSync%4Operational.evtx",
        "Microsoft-Windows-SettingSync-Azure%4Debug.evtx",
        "Microsoft-Windows-SettingSync-Azure%4Operational.evtx",

        "System.evtx",
        "Application.evtx",
        "Microsoft-Windows-WER-Diag%4Operational.evtx",
        "Microsoft-Windows-AppID%4Operational.evtx",
        "Microsoft-Windows-ApplicabilityEngine%4Operational.evtx",
        "Microsoft-Windows-WindowsUpdateClient%4Operational.evtx",
        "Microsoft-Windows-Winlogon%4Operational.evtx",

        "Microsoft-Windows-Shell-Core%4ActionCenter.evtx",
        "Microsoft-Windows-Shell-Core%4Operational.evtx",

        "Microsoft-Windows-User Profile Service%4Operational.evtx"
    )

$SourceDestinationPairs = 
        (
            (($UpgradeLogs + 'setup*.log'), ($LogsDestinationPath + '\Panther\')),
            (($WULogsPath + '*.etl'), ($LogsDestinationPath + '\WindowsUpdate\')),
            (($env:windir + '\Logs\CBS\CBS.log'), ($LogsDestinationPath + '\CBS\')),
            (($env:windir + '\Logs\DISM\DISM.log'), ($LogsDestinationPath + '\DISM\')),
            (($env:ProgramData + '\Microsoft\Windows\AppxProvisioning.xml'), ($LogsDestinationPath + '\')),
            (($env:ProgramData + '\Microsoft\Windows\AppRepository\StateRepository*'), ($LogsDestinationPath + '\StateRepository\')),
            (($env:ProgramData + '\Microsoft\Windows\WER\*'), ($LogsDestinationPath + '\WER\'))
        )

$RegExportsDestinationPath = $LogsDestinationPath + '\RegistryExports\'
New-Item -ItemType Directory -Force -Path $RegExportsDestinationPath > $null

$RegistrySourceDestinationPairs = 
        (
            (("HKEY_LOCAL_MACHINE\System\SetUp\Upgrade\AppX"), ($RegExportsDestinationPath + '\UpgradeAppx.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModel\StateRepository"), ($RegExportsDestinationPath + '\StateRepository.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE"), ($RegExportsDestinationPath + '\OOBE.reg')),
            (("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages"), ($RegExportsDestinationPath + '\UILanguages.reg')),
            (("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FastCache"), ($RegExportsDestinationPath + '\Fastcache.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Appx"), ($RegExportsDestinationPath + '\AppxPolicies.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx"), ($RegExportsDestinationPath + '\Appx.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppReadiness"), ($RegExportsDestinationPath + '\AppReadiness.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel"), ($RegExportsDestinationPath + '\AppModelSettings.reg')),
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModel"), ($RegExportsDestinationPath + '\AppModel.reg'))
        )

Write-Host 'Creating Destination Folder and Gathering Logs ' $LogsDestinationPath
New-Item -ItemType Directory -Force -Path $LogsDestinationPath > $null

Write-Progress -Activity 'Collecting Logs' -Id 10041

$EventLogsFolderPath = ($LogsDestinationPath + '\EventLogs\')
New-Item -ItemType Directory -Force -Path $EventLogsFolderPath > $null

# Copy Event Logs
foreach ($EventLogFile in $SystemEventLogFileList)
{
    $EventLogFilePath = ($SystemEventLogsPath + $EventLogFile)
    Copy-Item -Path $EventLogFilePath -Destination $EventLogsFolderPath -Force
}

foreach ($SDPair in $SourceDestinationPairs)
{
    New-Item -ItemType Directory -Force -Path $SDPair[1] > $null
    Copy-Item -Path $SDPair[0] -Destination $SDPair[1] -Recurse -Force > $null
}

foreach ($RegistrySDPair in $RegistrySourceDestinationPairs)
{
    reg export $RegistrySDPair[0] $RegistrySDPair[1] /y > $null
}

$AppDataPath = $env:LOCALAPPDATA + '\Packages'
$WindowsAppPath = $env:ProgramFiles + '\WindowsApps'
$AppRepositoryPath = $env:ProgramData + '\Microsoft\Windows\AppRepository'

Get-AppxPackage -AllUsers > ($LogsDestinationPath + '\GetAppxPackageAllUsersOutput.txt')
dir -Path $AppDataPath -Recurse -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\AppDataFolderList.txt')
dir -Path $WindowsAppPath -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\WindowsAppFolderList.txt')
dir -Path $AppRepositoryPath -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\AppRepositoryFileList.txt')

Write-Progress -Activity 'Creating Zip Archive' -Id 10041
Add-Type -Assembly "System.IO.Compression.FileSystem";
[System.IO.Compression.ZipFile]::CreateFromDirectory($LogsDestinationPath, $CabPath);

Write-Progress -Activity 'Done' -Completed -Id 10041
Write-Warning "Note: Below Zip file contains system, app and user information useful for diagnosing Application Installation Issues."
Write-Host 'Please upload zip and share a link : '
Write-Host $CabPath
Pause
