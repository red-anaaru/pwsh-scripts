<#
.SYNOPSIS
Helper script to start and stop a Teams ETW trace.

.DESCRIPTION
This script generates a Windows Performance Recording Profile (WPRP) file in a
temporary directory suitable for collecting traces with the Teams client, and
then starts or stops tracing.

.PARAMETER Start
Starts tracing.

.PARAMETER Stop
Stops and saves the trace to the specified location.

.PARAMETER Cancel
Stops (without saving) a currently running trace.

.PARAMETER IncludeDisk
Includes extra data regarding reads and writes of the filesystem will be
captured (performance heavy).

.PARAMETER Show
Outputs the WPRP file path and WPR.exe commands to start and stop the trace.

.EXAMPLE
.\CaptureTeamsLaunchTrace.ps1 -Start

<Launch the Teams app>

.\CaptureTeamsLaunchTrace.ps1 -Stop <"C:\path\to\save">
#>

# PowerShell script to start and then stop and save a running trace.
[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    [Parameter(ParameterSetName="Start")]
    [switch]$Start,
    [Parameter(ParameterSetName="Stop")]
    [ValidateScript({
        if (Test-Path $_) { $true }
        else { throw "Directory does not exist: $_" }
    })]
    [System.IO.DirectoryInfo]$Stop,
    [Parameter(ParameterSetName="Cancel")]
    [switch]$Cancel,
    [Parameter(ParameterSetName="Show")]
    [switch]$ShowCommands = $false,
    [Parameter(ParameterSetName="Help")]
    [switch]$Help = $false
)

if ($PSCmdlet.ParameterSetName -eq "Help") {
    Get-Help $MyInvocation.MyCommand.Definition
    return
}

$wprpContents = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Author="Microsoft Corporation" Copyright="Microsoft Corporation" Company="Microsoft Corporation">
  <Profiles>
    <SystemCollector Id="KernelCollector" Name="NT Kernel Logger">
      <BufferSize Value="1024"/>
      <Buffers Value="64"/>
    </SystemCollector>

    <EventCollector Id="EventCollector_WDGDEPAdex" Name="WDGDEPAdexCollector" HostGuestCorrelation="true">
      <BufferSize Value="256" />
      <Buffers Value="32" />
    </EventCollector>

    <SystemProvider Id="SystemProviderBase">
      <Keywords>
        <Keyword Value="Loader" />
        <Keyword Value="ProcessThread" />
        <CustomKeyword Value="0x00080000" />
      </Keywords>
      <Stacks>
        <CustomStack Value="0x0720" />
        <CustomStack Value="0x0721" />
        <CustomStack Value="0x0722" />
        <CustomStack Value="0x0723" />
        <CustomStack Value="0x0724" />
        <CustomStack Value="0x0725" />
        <CustomStack Value="0x0726" />
        <CustomStack Value="0x0727" />
        <CustomStack Value="0x0728" />
        <CustomStack Value="0x0729" />
        <CustomStack Value="0x072A" />
        <CustomStack Value="0x072B" />
        <CustomStack Value="0x072C" />
        <CustomStack Value="0x072D" />
      </Stacks>
    </SystemProvider>

    <!-- <EventProvider Id="Microsoft.Windows.AppXDeploymentServer" Name="fe762fb1-341a-4dd4-b399-be1868b3d918" Stack="true"> -->
    <EventProvider Id="Microsoft.Windows.AppXDeploymentServer" Name="fe762fb1-341a-4dd4-b399-be1868b3d918">
      <StackEventNameFilters FilterIn="true">
        <EventName Value="Failure"/>
      </StackEventNameFilters>
    </EventProvider>

    <!-- bindflt trace -->
    <EventProvider Id="EventProvider_BindFltTraceLoggingProvider" Name="1FD216EB-201E-4B4D-93CA-41F33D5A04EC" NonPagedMemory="true">
      <Keywords>
        <Keyword Value="0xFFFFFFFFFFFF"/>
      </Keywords>
    </EventProvider>

    <!-- wcifs trace -->
    <EventProvider Id="EventProvider_WcifsTraceLoggingProvider" Name="803CB23A-E32B-4200-BD82-D8A15919AC1B" Level="255">
      <Keywords>
        <Keyword Value="0xffffffff" />
      </Keywords>
    </EventProvider>

    <Profile Id="WDGDEPAdex.Verbose.File" Name="WDGDEPAdex" Description="Microsoft-Windows-WDG-Adex" LoggingMode="File" DetailLevel="Verbose">
      <Collectors>
        <SystemCollectorId Value="SystemCollector">
            <SystemProviderId Value="SystemProviderVerbose"/>
        </SystemCollectorId>
        <EventCollectorId Value="EventCollector_WDGDEPAdex">
          <EventProviders>
            <!-- WPRP puts EventProviderId elements before EventProvider elements -->
            <EventProviderId Value="Microsoft.Windows.AppXDeploymentServer"/>

            <!-- Filter Driver -->
            <EventProviderId Value="EventProvider_BindFltTraceLoggingProvider" />
            <EventProviderId Value="EventProvider_WcifsTraceLoggingProvider" />

            <!-- Unless otherwise specified, WPR captures with keywords 0xFFFFFFFFFFFF and level 0xFF, which is 'everything' -->
            <!-- WPP providers are special and need to explicitly specify keyword -->

            <EventProvider Id="Microsoft.Windows.AppXDeploymentExtensions" Name="d9e5f8fb-06b1-4796-8fa8-abb07f4fc662"/>
            <EventProvider Id="Microsoft.Gaming.Install" Name="7a881c79-ad79-5187-3c97-24e57db0b998"/>
            <EventProvider Id="Microsoft.Gaming.GameFlt" Name="4C4D0723-7671-5F16-48ED-7C5936102682"/>
            <EventProvider Id="Microsoft.Windows.AppXDeploymentClient.WPP" Name="8FD4B82B-602F-4470-8577-CBB56F702EBF">
              <Keywords>
                <Keyword Value="0xFFFFFFFFFFFF"/>
              </Keywords>
            </EventProvider>
            <EventProvider Id="Microsoft.Windows.AppXDeploymentClient" Name="b89fa39d-0d71-41c6-ba55-effb40eb2098"/>

            <!-- AppxAllUserStore has tracelogging and WPP -->
            <EventProvider Id="Microsoft.Windows.AppXAllUserStore" Name="4dab1c21-6842-4376-b7aa-6629aa5e0d2c"/>
            <EventProvider Id="Microsoft.Windows.AppXAllUserStore.WPP" Name="901E537A-8D3C-4AC6-B682-4D0FD10CEE92">
              <Keywords>
                <Keyword Value="0xFFFFFFFFFFFF"/>
              </Keywords>
            </EventProvider>

            <!-- Appreadiness etw and WPP -->
            <EventProvider Id="Microsoft.Windows.AppReadiness" Name="f0be35f8-237b-4814-86b5-ade51192e503"/>
            <EventProvider Id="AppReadiness.WPP" Name="c94526b9-c642-489c-adfc-224530dda439">
              <Keywords>
                <Keyword Value="0xFFFFFFFFFFFF"/>
              </Keywords>
            </EventProvider>

            <EventProvider Id="Microsoft-Windows-AppxPackagingOM" Name="BA723D81-0D0C-4F1E-80C8-54740F508DDF"/>
            <EventProvider Id="Microsoft.Windows.AppxPackaging" Name="fe0ab4b4-19b6-485b-89bb-60fd931fdd56"/>

            <!-- Deployment server has both tracelogging & manifested. Note the BA44.. is WPP and many not show in WPA -->
            <EventProvider Id="Microsoft.Windows.AppXDeployment.Server" Name="3F471139-ACB7-4A01-B7A7-FF5DA4BA2D43"/>
            <EventProvider Id="Microsoft.Windows.AppXDeploymentServer.WPP" Name="BA44067A-3C4B-459C-A8F6-18F0D3CF0870">
              <Keywords>
                <Keyword Value="0xFFFFFFFFFFFF"/>
              </Keywords>
            </EventProvider>
            <EventProvider Id="Microsoft-Windows-AppXDeploymentFallback" Name="aa1b41d3-d193-4660-9b47-dd701ba55841"/>
            <EventProvider Id="Microsoft-Windows-AppXDeployment" Name="8127F6D4-59F9-4abf-8952-3E3A02073D5F"/>

            <!-- Deployment: Windows App SDK -->
            <EventProvider Id="Microsoft.WindowsAppRuntime.Deployment" Name="838d2cc1-0efb-564a-47bf-faba17949992"/>
            <EventProvider Id="Microsoft.WindowsAppRuntime.DeploymentAgent" Name="24d30cc4-c994-597a-3a2f-c0653d641b0f"/>

            <EventProvider Id="Microsoft.Windows.AppModel.TileDataModel" Name="594bf743-ce2e-48ee-83ee-3d50a0add692"/>
            <EventProvider Id="Microsoft.Windows.AppModel.Tiles" Name="98CCAAD9-6464-48D7-9A66-C13718226668"/>

            <!-- StateRepository has manifested & tracelogging events -->
            <EventProvider Id="Microsoft.Windows.StateRepository" Name="89592015-D996-4636-8F61-066B5D4DD739"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Common" Name="1ded4f74-5def-425d-ae55-4fd4e9bbe0a7"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Core" Name="746622e1-9381-4507-be68-2e6b55f81070"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Client" Name="a89336e8-e6cf-485c-9c6a-ddb6614f278a"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Broker" Name="312326fa-036d-4888-bc77-c3de2ff9ae06"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Service" Name="551ff9b3-0b7e-4408-b008-0068c8da2ff1"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Tools" Name="7237c668-b9a2-4fbd-9987-87d4502b9e00"/>
            <EventProvider Id="Microsoft.Windows.StateRepository.Upgrade" Name="80a49605-87cb-4480-be97-d6ccb3dde5f2"/>

            <!-- Dynamic Dependencies: Windows App SDK -->
            <EventProvider Id="Microsoft.WindowsAppRuntime.MddBootstrap" Name="d71ecd75-2924-589c-16dd-68208d1b4015"/>

            <EventProvider Id="Microsoft-OneCore-AppModel-Autologger" Name="3C42000F-CC27-48C3-A005-48F6E38B131F"/>
            <EventProvider Id="Microsoft-WindowsPhone-AppPlatProvider-Test1" Name="1230dd62-03b6-4a26-92f5-06374d678571"/>
            <EventProvider Id="Microsoft-WindowsPhone-AppPlatProvider-Test2" Name="EB65A492-86C0-406A-BACE-9912D595BD69"/>

            <!-- State and ApplicationData -->
            <EventProvider Id="Microsoft.Windows.AppModel.Runtime" Name="F1EF270A-0D32-4352-BA52-DBAB41E1D859"/>
            <EventProvider Id="Microsoft.Windows.AppModel.State" Name="BFF15E13-81BF-45EE-8B16-7CFEAD00DA86"/>
            <EventProvider Id="Microsoft.Windows.AppModel.StateManagerTelemetry" Name="41B5F6E6-F53C-4645-A991-135C2011C074" />
            <EventProvider Id="Microsoft-Windows-Roaming" Name="5B5AB841-7D2E-4A95-BB4F-095CDF66D8F0"/>
            <EventProvider Id="Microsoft-Windows-SettingMonitor" Name="c1779399-4943-4610-83ec-cace7da7c2df"/>
            <EventProvider Id="Microsoft-Windows-SettingSyncCore" Name="83D6E83B-900B-48a3-9835-57656B6F6474"/>
            <EventProvider Id="Microsoft-Windows-StateManager" Name="BFF15E13-81BF-45EE-8B16-7CFEAD00DA86"/>

            <!-- CoreUIComponents has manifested events -->
            <EventProvider Id="Microsoft-WindowsPhone-CoreUIComponents" Name="a0b7550f-4e9a-4f03-ad41-b8042d06a2f7"/>

            <!-- COM -->
            <EventProvider Id="ComBaseTraceLoggingProvider" Name="1aff6089-e863-4d36-bdfd-3581f07440be"/>

            <!-- COM call stacks -->
            <EventProvider Id="CE_Microsoft-Windows-COM-Perf_Stacks" Name="b8d6861b-d20f-4eec-bbae-87e0dd80602b" Stack="true">
              <Keywords>
                <Keyword Value="0x1000000000000000"/>
              </Keywords>
            </EventProvider>

            <!-- CLIP -->
            <EventProvider Id="Microsoft-Client-Licensing-Platform-Instrumentation" Name="B6CC0D55-9ECC-49A8-B929-2B9022426F2A"/>
            <EventProvider Id="Microsoft.Windows.LicenseManager.Telemetry" Name="AF9F58EC-0C04-4BE9-9EB5-55FF6DBE72D7"/>
            <EventProvider Id="ClipSvcProvider" Name="6AF9E939-1D95-430A-AFA3-7526FADEE37D">
              <Keywords>
                <Keyword Value="0x4000000000000000"/>
              </Keywords>
            </EventProvider>

            <!-- KernelBase -->
            <EventProvider Id="Microsoft.Windows.Kernel.KernelBase.Fallback" Name="{b749553b-d950-5e03-6282-3145a61b1002}"/>

            <!-- Activation Execution -->
            <EventProvider Id="Microsoft.Windows.Security.LUA" Name="be928fd4-50ba-57ca-b6b8-925dab19c3bf" />
            <EventProvider Id="Microsoft.Windows.ResourceManager.Info" Name="4180c4f7-e238-5519-338f-ec214f0b49aa" />
            <EventProvider Id="Microsoft.Windows.ResourceManager.Verbose" Name="4180c4f7-e238-5519-338f-ec214f0b49aa" />
            <EventProvider Id="Microsoft-WindowsPhone-ExecManLogPublisher" Name="82c8ad90-5f3c-11be-bd9a-85bb5f50dfa4" />
            <EventProvider Id="Microsoft.Windows.BackgroundManager" Name="1941f2b9-0939-5d15-d529-cd333c8fed83" />
            <EventProvider Id="Microsoft.Windows.BrokerInfrastructure" Name="63b6c2d2-0440-44de-a674-aa51a251b123" />
            <EventProvider Id="Microsoft-Windows-ProcessStateManager" Name="D49918CF-9489-4BF1-9D7B-014D864CF71F" />
            <EventProvider Id="Microsoft-Windows-AppModel-Exec" Name="EB65A492-86C0-406A-BACE-9912D595BD69" />
            <EventProvider Id="Microsoft.Windows.AppLifeCycle" Name="EF00584A-2655-462C-BC24-E7DE630E7FBF" />
            <EventProvider Id="Microsoft.Windows.ResourcePolicy" Name="969e8d6b-df02-56e3-a058-ec3bef103534" />
            <EventProvider Id="Microsoft.Windows.ProcessStateManager" Name="0001376b-930d-50cd-2b29-491ca938cd54" />
            <EventProvider Id="Microsoft.Windows.ProcessLifetimeManager" Name="072665fb-8953-5a85-931d-d06aeab3d109" />
            <EventProvider Id="Microsoft.Windows.ForegroundManager" Name="aa6f6a10-8a13-417d-8799-52361684bd76" />
            <EventProvider Id="Microsoft.Windows.ActivationManager" Name="cf7f94b3-08dc-5257-422f-497d7dc86ab3" />
            <EventProvider Id="Microsoft.Windows.Application.Service" Name="ac01ece8-0b79-5cdb-9615-1b6a4c5fc871" />
            <EventProvider Id="Microsoft.Windows.ApplicationModel.DesktopAppx" Name="5526aed1-f6e5-5896-cbf0-27d9f59b6be7" />
            <EventProvider Id="ActivationManager" Name="cf7f94b3-08dc-5257-422f-497d7dc86ab3" />
            <EventProvider Id="Microsoft.Windows.HostActivityManager" Name="f6a774e5-2fc7-5151-6220-e514f1f387b6"/>
            <EventProvider Id="Microsoft.Windows.HostIdStore" Name="A6A9CE06-035F-40CB-829B-EBB822697591"/>
            <EventProvider Id="CustomInstall" Name="24241768-581f-4239-9994-ed874701a2f5"/>
            <EventProvider Id="Microsoft.Windows.ShellExecute" Name="382B5E24-181E-417F-A8D6-2155F749E724" />
            <EventProvider Id="EventProvider_WindowsSystemLauncher_Client"  Name="76d1c1d6-4cee-5e0c-ee01-cd252eef4036"/>
            <EventProvider Id="EventProvider_WindowsSystemLauncher_Service" Name="810d9efb-88db-54ff-3703-9f5e54cc74fb"/>
            <EventProvider Id="EventProvider_WindowsSystemLauncher_Desktop" Name="E3185DA8-ECF4-4051-8BF1-8B6602E3577D"/>

            <!-- Activation Execution: Windows App SDK -->
            <EventProvider Id="Microsoft.Windows.AppLifecycle" Name="129A9300-9EA3-40B1-922B-43D46349BB91"/>

            <!-- Watson Error Reporting -->
            <EventProvider Id="Microsoft.Windows.FaultReporting" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>
            <EventProvider Id="Microsoft.Windows.WindowsErrorReporting" Name="CC79CF77-70D9-4082-9B52-23F3A3E92FE4"/>
            <EventProvider Id="Microsoft.Windows.HangReporting" Name="3E0D88DE-AE5C-438A-BB1C-C2E627F8AECB"/>

            <!-- Kozani -->
            <EventProvider Id="Microsoft.Kozani.AppGraph" Name="b731824-91e7-47ae-ae99-e9dd6c6379d"/>
            <EventProvider Id="Microsoft.Kozani.HostRuntime" Name="896ccbc-b8cd-41fe-a506-5f4e7c60a97"/>
            <EventProvider Id="Microsoft.Kozani.Manager" Name="3d44131-26c8-471e-b9d6-fba649e59cf"/>
            <EventProvider Id="Microsoft.Kozani.ManagerRuntime" Name="4ccf6d3-5878-4a9f-82e3-fadbac2515e"/>
            <EventProvider Id="Microsoft.Kozani.Package" Name="0042f04-7f33-4de2-ab4f-c31e267c891"/>
            <EventProvider Id="Microsoft.Kozani.RemoteManager" Name="8f82421-f1da-44b4-9bdf-4685a130b75"/>
            <EventProvider Id="Microsoft.Kozani.RemoteManagerLauncher" Name="6e9cc70-6a58-48f6-831f-521204545ed"/>
            <EventProvider Id="Microsoft.Kozani.SendToLocal" Name="7202135-35d6-4636-beba-8be8819519c"/>
            <EventProvider Id="Microsoft.Kozani.SendToRemote" Name="4b11fe1-aca7-4b6a-b9eb-578decfca2f"/>
            <EventProvider Id="Microsoft.Kozani.Settings" Name="8c3ec79-97b4-48f0-9df4-b5282c0c5a9"/>
            <EventProvider Id="Microsoft.Kozani.MakeMSIX" Name="add42f7-8804-4986-82da-c7517747634"/>

            <!-- Push Notifications: Windows App SDK -->
            <EventProvider Id="Microsoft.WindowsAppSDK.Notifications.AppNotificationBuilderTelemetry" Name="6f23f3a8-1420-4814-83c7-c752565aad22"/>
            <EventProvider Id="Microsoft.WindowsAppSDK.Notifications.AppNotificationTelemetry" Name="1825c850-a487-537d-b768-f0ab298d2565"/>
            <EventProvider Id="Microsoft.WindowsAppSDK.Notifications.PushNotificationLongRunningTaskTelemetry" Name="76c12936-0ba7-46ba-be2b-ce492e4bcf01"/>
            <EventProvider Id="Microsoft.WindowsAppSDK.Notifications.PushNotificationTelemetry" Name="7c1b07ef-a7c0-56d1-5456-385ebd4412b2"/>

            <!-- Power Notifications: Windows App SDK -->
            <EventProvider Id="Microsoft.WindowsAppSDK.System.PowerNotifications" Name="a1b12e2c-12d9-564e-2ea1-2894ffcc7cc5"/>

            <!-- WindowsAppSDK -->
            <EventProvider Id="Microsoft.WindowsAppRuntimeInstaller" Name="7028b782-2ccf-5a66-0008-9b040616d425"/>
          </EventProviders>
        </EventCollectorId>
      </Collectors>
    </Profile>
  </Profiles>
</WindowsPerformanceRecorder>
"@

if ($PSCmdlet.ParameterSetName -eq "Cancel") {
    Write-Host "Cancelling ETW tracing"
    wpr.exe -cancel
}

# Get the current date and time in the specified format
$currentDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Save a temp WPRP file for starting a trace
$tempPath = $env:Temp

$wprpPath = Join-Path -Path $tempPath -ChildPath ("teamslaunch_" + $currentDateTime + ".wprp")
Set-Content -Path $wprpPath -Value $wprpContents

if($PSCmdlet.ParameterSetName -eq "Show") {
    Write-Host "WPRP file: $wprpPath"
    Write-Host "To collect trace: wpr.exe -start $wprpPath -filemode"
    Write-Host "To stop trace: wpr.exe -stop teamslaunch_" + $currentDateTime + ".etl"
    exit
}

if ($PSCmdlet.ParameterSetName -eq "Start") {
    Write-Host "Starting ETW tracing"
    wpr.exe -start $wprpPath -filemode
}

if ($PSCmdlet.ParameterSetName -eq "Stop") {
    $out = $Stop
    # Create the out directory if it doesn't exist
    if (-not (Test-Path -Path $out)) {
        New-Item -Path $out -ItemType Directory
        Write-Host "Created: $out"
    }

    # Capturing the ETW trace
    $etlPath = Join-Path -Path $out -ChildPath ("teamslaunch_" + $currentDateTime + ".etl")
    Write-Host "Stopping ETW tracing"
    wpr.exe -stop $etlPath

    # Remove the WPRP file
    Remove-Item -Path $wprpPath
}
