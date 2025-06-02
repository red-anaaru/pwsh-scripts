#
# GetDeploymentLogsWithOptions.ps1 is a PowerShell script designed to collect
# various logs and system information to diagnose App deployment problems. 
#

<#
.SYNOPSIS
    Collects various logs and system information to diagnose Windows App deployment problems.

.DESCRIPTION
    GetDeploymentLogsWithOptions.ps1 is a comprehensive PowerShell script that gathers system, event, registry, and tracing logs relevant to Windows AppX deployment and troubleshooting. It supports both immediate and tracing-enabled log collection, including boot tracing and Procmon integration. The script can be run as administrator and will relaunch itself elevated if needed.

.PARAMETER Force
    If specified, suppresses user prompts and pauses.

.PARAMETER EnableTracing
    Enables ETW tracing during log collection.

.PARAMETER SkipBeforeCheckpoint
    Skips the collection of static data before tracing begins.

.PARAMETER StartBoot
    Enables boot tracing. Must be used with -EnableTracing.

.PARAMETER StopBoot
    Stops boot tracing and collects logs.

.PARAMETER CancelBoot
    Cancels any pending ETW boot tracing.

.PARAMETER ProcmonPath
    Optional. Path to Procmon.exe for collecting Procmon traces.

.PARAMETER TargetPackageFamilyName
    Optional. The package family name of the app to collect additional ACL and registry data for.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1
    Runs the script interactively, prompting the user to choose between immediate log collection or tracing.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -EnableTracing
    Collects logs with ETW tracing enabled.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -EnableTracing -StartBoot
    Prepares the system for boot tracing. After reboot and repro, run with -StopBoot to collect logs.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -StopBoot
    Stops boot tracing and collects logs after a repro.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -CancelBoot
    Cancels any pending ETW boot tracing.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -EnableTracing -ProcmonPath "C:\Tools\Procmon.exe"
    Collects logs with ETW tracing and Procmon trace.

.EXAMPLE
    .\GetDeploymentLogsWithOptions.ps1 -TargetPackageFamilyName "ContosoApp_12345678"
    Collects logs and additional ACL/registry data for the specified app package family.

.NOTES
    Author: Microsoft Corporation
    Version: 1.0.8
    This script must be run as administrator. It will relaunch itself elevated if needed.
    The output is a zip file containing all collected logs, suitable for sharing with support teams.
#>
#
# GetDeploymentLogsWithOptions.ps1 is a PowerShell script designed to collect
# various logs and system information to diagnose App deployment problems. 
#
param(
    [switch]$Force = $false,
    [switch]$EnableTracing = $false,
    [switch]$SkipBeforeCheckpoint = $false,
    [Parameter(Mandatory=$false)]
    [switch]$StartBoot = $false,
    [Parameter(Mandatory=$false)]
    [switch]$StopBoot = $false,
    [Parameter(Mandatory=$false)]
    [switch]$CancelBoot = $false,
    [Parameter(Mandatory=$false)]
    [System.String]$ProcmonPath = "",
    [Parameter(Mandatory=$false)]
    [System.String]$TargetPackageFamilyName = ""
)

# Function to get the current timestamp
function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Function to read a single key press
function Read-KeyPress {
    $key = [System.Console]::ReadKey($true)
    return $key.KeyChar.ToString().ToUpperInvariant()
}

function PrintMessageAndExit {
    param(
        [string]$ErrorMessage,
        [int]$ReturnCode
    )
    Write-Host $ErrorMessage
    if (!$Force)
    {
        Pause
    }
    exit $ReturnCode
}

function Get-StartBvtWprp {
 $startBvtXml = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Comments="Test" Company="Microsoft Corporation" Copyright="Microsoft Corporation">
  <Profiles>
    <SystemProvider Id="SystemProvider_Winperf_Light" Base="SystemProvider_Base">
      <Keywords Operation="Add">
        <Keyword Value="CompactCSwitch"/>
        <Keyword Value="CSwitch"/>
        <Keyword Value="Memory"/>
        <Keyword Value="VirtualAllocation"/>
        <Keyword Value="ReferenceSet"/>
        <Keyword Value="SampledProfile"/>
        <Keyword Value="ReadyThread"/>
        <Keyword Value="MemoryInfo"/>
        <Keyword Value="MemoryInfoWS"/>
        <Keyword Value="ProcessThread" />
        <Keyword Value="Loader" />
        <Keyword Value="ProcessCounter" />
        <Keyword Value="ThreadPriority" />
      </Keywords>
      <Stacks>
        <Stack Value="CSwitch"/>
        <Stack Value="ReadyThread"/>
        <Stack Value="SampledProfile"/>
      </Stacks>
    </SystemProvider>

    <SystemProvider Id="SystemProvider_Winperf_Memory" Base="SystemProvider_Base">
      <Keywords Operation="Add">
        <Keyword Value="CompactCSwitch"/>
        <Keyword Value="CSwitch"/>
        <Keyword Value="Memory"/>
        <Keyword Value="VirtualAllocation"/>
        <Keyword Value="ReferenceSet"/>
        <Keyword Value="Interrupt"/>
        <Keyword Value="SampledProfile"/>
        <Keyword Value="ReadyThread"/>
        <Keyword Value="MemoryInfo"/>
        <Keyword Value="MemoryInfoWS"/>
        <Keyword Value="FootPrint"/>
        <Keyword Value="ProcessThread" />
        <Keyword Value="Loader" />
        <Keyword Value="IdleStates"/>
        <Keyword Value="DPC"/>
        <Keyword Value="ProcessCounter" />
        <Keyword Value="ThreadPriority" />

        <CustomKeyword Value="0x00040000"/> <!--PERF_DBGPRINT-->
        <CustomKeyword Value="0xDFFFFFFF"/> <!--PERF_SYSCFG_ALL-->
        <CustomKeyword Value="0x20000200"/> <!--PERF_DISPATCHER-->
      </Keywords>
      <Stacks>
        <Stack Value="CSwitch"/>
        <Stack Value="ReadyThread"/>
        <Stack Value="SampledProfile"/>
        <Stack Value="ThreadDelete"/>
        <Stack Value="ImageLoad"/>

        <Stack Value="ThreadCreate" />
        <Stack Value="ProcessCreate" />
        <Stack Value="ProcessDelete" />

        <Stack Value="HeapCreate" />
        <Stack Value="PageAccess" />
        <Stack Value="PageAccessEx" />
        <Stack Value="PagefileMappedSectionCreate" />
        <Stack Value="PagefileMappedSectionDelete" />
        <Stack Value="PageRangeAccess" />
        <Stack Value="PageRangeRelease" />
        <Stack Value="PageRelease" />
        <Stack Value="PageRemovedfromWorkingSet" />
        <Stack Value="VirtualAllocation" />
        <Stack Value="VirtualFree" />
      </Stacks>
    </SystemProvider>

    <EventProvider Id="EventProvider-Microsoft-Windows-TestExecution" Name="Microsoft-Windows-TestExecution"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.TestExecution.WexLogger" Name="40c4df8b-00a9-5159-62bc-9bbc5ee78a29"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-XAML" Name="531a35ab-63ce-4bcf-aa98-f88c7a89e455" Level="4"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-Shell-Launcher" Name="3d6120a6-0986-51c4-213a-e2975903051d" />
    <EventProvider Id="EventProvider-Microsoft.Windows.Health.TestInProduction" Name="50109fbd-6d85-5815-731e-c907eca1607b" />
    <EventProvider Id="EventProvider-Microsoft.Windows.ShellCommon.StartLayout" Name="1a554939-2d19-5b10-ceda-ee4dd6910d59" />
    <EventProvider Id="EventProvider-Microsoft_Windows_ForegroundManager" Name="AA6F6A10-8A13-417D-8799-52361684BD76" />
    <EventProvider Id="EventProvider-Microsoft_Windows_ActivationManager" Name="cf7f94b3-08dc-5257-422f-497d7dc86ab3" />
    <EventProvider Id="EventProvider-Microsoft_Windows_AppModel_Exec" Name="eb65a492-86c0-406a-bace-9912d595bd69" />
    <EventProvider Id="EventProvider-Microsoft-Windows-ProcessLifetimeManager" Name="072665fb-8953-5a85-931d-d06aeab3d109" />
    <EventProvider Id="EventProvider-Microsoft-Windows-CoreUIComponents" Name="a0b7550f-4e9a-4f03-ad41-b8042d06a2f7"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-CoreWindow" Name="A3D95055-34CC-4E4A-B99F-EC88F5370495"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Desktop.Shell.ViewManagerInterop" Name="15322370-3694-59f5-f979-0c7a918b81da"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.SingleViewExperience" Name="2ca51213-29c5-564f-fd60-355148e8b47f"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.ExperienceHost" Name="53e167d9-e368-4150-9563-4ed25700ccc7"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-WindowsErrorReporting" Name="cc79cf77-70d9-4082-9b52-23f3a3e92fe4"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.FaultReportingTracingGuid" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.StartMenu.Experience" Name="d3e36643-28fd-5ccd-99b7-3b13c721ee51"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.ErrorHandling.Fallback" Name="bf4c9654-66d1-5720-7b51-d2ae226735ea"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.DataStoreCache" Name="a331d81d-2f6f-50de-2461-a5530d0465d7"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.DataStoreTransformers" Name="6cfc5fc0-7e30-51e0-898b-57ac43152695"/>
    <EventProvider Id="EventProvider-WindowsInternal.Shell.UnifiedTile" Name="F2CDC8A0-AF2C-450F-9859-3251CCE0D234"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.ShellExperienceDispatcher" Name="273c19b2-6643-5a58-6288-c336d3688b8d"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-Immersive-Shell" Name="Microsoft-Windows-Immersive-Shell">
      <Keywords>
        <Keyword Value="0xFFFFFFFFFFFFFFFF"/>
      </Keywords>
    </EventProvider>
    <EventProvider Id="EventProvider-Microsoft.Windows.ResourceManager" Name="4180c4f7-e238-5519-338f-ec214f0b49aa">
      <CaptureStateOnSave>
        <Keyword Value="0xFFFFFFFFFFFFFF"/>
      </CaptureStateOnSave>
    </EventProvider>
    <EventProvider Id="EventProvider-Microsoft.Windows.HostActivityManager" Name="f6a774e5-2fc7-5151-6220-e514f1f387b6">
      <CaptureStateOnSave>
        <Keyword Value="0xFFFFFFFFFFFFFF"/>
      </CaptureStateOnSave>
    </EventProvider>
    <EventProvider Id="EventProvider-Microsoft.Windows.BackgroundManager" Name="1941f2b9-0939-5d15-d529-cd333c8fed83" />
    <EventProvider Id="EventProvider-Microsoft.Windows.BrokerInfrastructure" Name="63b6c2d2-0440-44de-a674-aa51a251b123" />
    <EventProvider Id="EventProvider-Microsoft-Windows-ProcessStateManager" Name="D49918CF-9489-4BF1-9D7B-014D864CF71F" />
    <EventProvider Id="EventProvider-Microsoft.Windows.ProcessStateManager" Name="0001376b-930d-50cd-2b29-491ca938cd54" />
    <EventProvider Id="EventProvider-Microsoft-Windows-AppModel-Exec" Name="EB65A492-86C0-406A-BACE-9912D595BD69" />
    <EventProvider Id="EventProvider-Microsoft-WindowsPhone-CoreUIComponents" Name="a0b7550f-4e9a-4f03-ad41-b8042d06a2f7">
      <!-- N.B. The high-order 4 bytes are explicitly omitted because they cause chatty and low value events. -->
      <Keywords>
        <Keyword Value="0xffffffff"/>
      </Keywords>
    </EventProvider>
    <EventProvider Id="EventProvider-Microsoft.Windows.AppLifeCycle" Name="EF00584A-2655-462C-BC24-E7DE630E7FBF" />
    <EventProvider Id="EventProvider-Microsoft.Windows.ResourcePolicy" Name="969e8d6b-df02-56e3-a058-ec3bef103534" />
    <EventProvider Id="EventProvider-CombaseTraceLoggingProvider" Name="1aff6089-e863-4d36-bdfd-3581f07440be" />
    <EventProvider Id="EventProvider-Microsoft.Windows.AppModel.Tiles" Name="98CCAAD9-6464-48D7-9A66-C13718226668"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository" Name="89592015-D996-4636-8F61-066B5D4DD739"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Common" Name="1ded4f74-5def-425d-ae55-4fd4e9bbe0a7"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Client" Name="a89336e8-e6cf-485c-9c6a-ddb6614f278a"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Broker" Name="312326fa-036d-4888-bc77-c3de2ff9ae06"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Service" Name="551ff9b3-0b7e-4408-b008-0068c8da2ff1"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Tools" Name="7237c668-b9a2-4fbd-9987-87d4502b9e00"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.StateRepository.Upgrade" Name="80a49605-87cb-4480-be97-d6ccb3dde5f2"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-AppXDeployment" Name="8127F6D4-59F9-4abf-8952-3E3A02073D5F"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.AppXDeployment.Server" Name="3F471139-ACB7-4A01-B7A7-FF5DA4BA2D43"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-AppModel-Runtime" Name="F1EF270A-0D32-4352-BA52-DBAB41E1D859"/>
    <EventProvider Id="Microsoft-Windows-TwinAPI-Events" Name="5f0e257f-c224-43e5-9555-2adcb8540a58" />
    <EventProvider Id="EventProvider-Microsoft.Windows.CoreApplication" Level="5" Name="a9da4dcc-e78e-5ce7-4078-411a9928f082"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-ComposableShell-CoreShell" Name="48DCC4B8-1A33-4625-B042-95CE02602863" Level="5" />
    <EventProvider Id="EventProvider-Microsoft-Windows-ComposableShell-Framework-Composer" Name="CC459D2F-F4BD-4E6C-901E-08BEA752A7D3" Level="5" />
    <EventProvider Id="EventProvider-Microsoft-Windows-ComposableShell-Components-Viewhosting" Name="8a562815-f309-41ff-a52c-ec0764f8daee" Level="5" />
    <EventProvider Id="EventProvider-Microsoft-Windows-ComposableShell-Products-Common" Name="aa41497c-829b-5bef-a73f-0c5f43ab6be8" />
    <EventProvider Id="EventProvider_Microsoft-Windows-Shell-CortanaProactive" Name="0e6f34b3-0637-55ab-f0bb-8b8fa83eda04"/>
    <EventProvider Id="EventProvider_Microsoft.Windows.Shell.CortanaSearch" Name="E34441D9-5BCF-4958-B787-3BF824F362D7"/>
    <EventProvider Id="EventProvider_Microsoft.Windows.Shell.CloudStore.Internal" Name="c45c91e9-3750-5f9d-63c2-ec9d4991fcda"/>
    <EventProvider Id="EventProvider-Microsoft-Windows-Shell-AppResolver" Name="39ddcb8d-ef82-5c84-89ca-09580bf0a947"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.JumpView" Name="f6148764-178d-4a19-b984-14b90f352c9c"/>
    <EventProvider Id="EventProvider-Microsoft.Windows.Shell.JumpView-JumpViewBroker" Name="c0f1d44d-efea-4cc3-a68b-d7a3af9ec850"/>
    <EventProvider Id="Microsoft.Windows.Start.SharedStartModel.Cache" Name="66FEB609-F4B6-4224-BF13-121F8A4829B4"/>
    <EventProvider Id="Microsoft.Windows.UI.Shell.StartUI.WinRTHelpers" Name="36F1D421-D446-43AE-8AA7-A4F85CB176D3"/>
    <EventProvider Id="Microsoft.Windows.IrisService" Name="B84EB1F9-E572-5B45-34AB-56CDF25A2A85"/>
    <EventProvider Id="Microsoft.Windows.ApplicationModel.DesktopAppx" Name="5526AED1-F6E5-5896-CBF0-27D9F59B6BE7"/>
    <EventProvider Id="Microsoft.Windows.Security.CustomCapability" Name="36A3A51F-7E30-4005-9ACB-C435056BFB46"/>
    <EventProvider Id="Microsoft.Windows.AppListBackup.AppListBackupImpl" Name="73F03CB2-E523-55D3-9A6A-46855F5AEAE7"/>
    <EventProvider Id="Microsoft.Windows.Shell.Taskbar" Name="Df8Dab3F-B1C9-58D3-2Ea1-4C08592Bb71B"/>
    <EventProvider Id="Microsoft.Windows.AppLifeCycle.UI" Name="EE97CDC4-B095-5C70-6E37-A541EB74C2B5"/>

    <!-- Photon providers -->
    <EventProvider Id="Microsoft.Windows.Services.Experiences.ExperienceExtensions" Name="FE276891-7D1F-4D1B-8B22-427048D079FE"/>
    <EventProvider Id="Microsoft.Windows.Services.Experiences.PackManager" Name="9A48DC1A-9E9E-4D01-AB50-EDC14668CF0C"/>
    <EventProvider Id="Microsoft.Windows.Services.Experiences.Provider" Name="d49f44b4-27f8-473c-8e13-ff4524224c3f"/>

    <!-- Render perf providers -->
    <EventProvider Id="EventProvider-Microsoft-Windows-Dwm-Core" Name="Microsoft-Windows-Dwm-Core" />
    <EventProvider Id="EventProvider-Microsoft-Windows-DxgKrnl" Name="Microsoft-Windows-DxgKrnl" NonPagedMemory="true" Level="5">
      <Keywords>
        <Keyword Value="0x45"/>
      </Keywords>
      <CaptureStateOnSave>
        <Keyword Value="0x45"/>
      </CaptureStateOnSave>
    </EventProvider>
    <EventProvider Id="EventProvider-Microsoft-Windows-Win32k" Name="Microsoft-Windows-Win32k" />

    <!-- Power providers -->
    <EventProvider
        Id="EventProvider_Microsoft-Windows-Kernel-Power"
        Name="Microsoft-Windows-Kernel-Power"
        NonPagedMemory="true"
        Level="6"
        >
      <Keywords>
        <Keyword Value="0xFFFFFFFF"/>
      </Keywords>
      <CaptureStateOnSave>
        <Keyword Value="0xFFFFFFFF"/>
      </CaptureStateOnSave>
    </EventProvider>
    <EventProvider
       Id="EventProvider_Microsoft-Windows-Kernel-Processor-Power"
       Name="Microsoft-Windows-Kernel-Processor-Power"
       NonPagedMemory="true"
       Level="6"
        >
      <Keywords>
        <Keyword Value="0xFFFFFFFF"/>
      </Keywords>
      <CaptureStateOnSave>
        <Keyword Value="0xFFFFFFFF"/>
      </CaptureStateOnSave>
    </EventProvider>

    <EventProvider Id="Microsoft.Windows.Application.Service" Name="ac01ece8-0b79-5cdb-9615-1b6a4c5fc871" />
    <EventProvider Id="Microsoft.Windows.Shell.Desktop.LogonFramework" Name="04d28e21-00aa-5228-cfd0-d70863aa5ce9" />

    <Profile Id="StartBVTProfile.Verbose.File" Name="StartBVTProfile" Base="GeneralProfile.Light.File" LoggingMode="File" DetailLevel="Verbose" Description="StartBVTProfile.Verbose.File" Default="true">
      <Collectors Operation="Add">
        <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
          <BufferSize Value="1024" />
          <Buffers Value="3" PercentageOfTotalMemory="true"/>
          <EventProviders Operation="Add">
            <EventProviderId Value="EventProvider-Microsoft-Windows-TestExecution"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.TestExecution.WexLogger"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-XAML"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-Launcher"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Health.TestInProduction"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellCommon.StartLayout"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ForegroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ActivationManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_AppModel_Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessLifetimeManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreWindow"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Desktop.Shell.ViewManagerInterop"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.SingleViewExperience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.ExperienceHost"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.StartMenu.Experience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ErrorHandling.Fallback"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreCache"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreTransformers"/>
            <EventProviderId Value="EventProvider-WindowsInternal.Shell.UnifiedTile"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellExperienceDispatcher"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Immersive-Shell"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourceManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.HostActivityManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BackgroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BrokerInfrastructure"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-WindowsPhone-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppLifeCycle"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourcePolicy"/>
            <EventProviderId Value="EventProvider-CombaseTraceLoggingProvider"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppModel.Tiles"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Common"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Client"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Broker"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Service"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Tools"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Upgrade"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppXDeployment"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppXDeployment.Server"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Runtime"/>
            <EventProviderId Value="Microsoft-Windows-TwinAPI-Events"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.CoreApplication"/>
            <EventProviderId Value="EventProvider_Microsoft-Windows-Shell-CortanaProactive"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CortanaSearch"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CloudStore.Internal"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-AppResolver"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView-JumpViewBroker"/>
            <EventProviderId Value="Microsoft.Windows.Application.Service"/>
            <EventProviderId Value="Microsoft.Windows.Shell.Desktop.LogonFramework"/>
            <EventProviderId Value="Microsoft.Windows.Start.SharedStartModel.Cache"/>
            <EventProviderId Value="Microsoft.Windows.UI.Shell.StartUI.WinRTHelpers"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.ExperienceExtensions"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.PackManager"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.Provider"/>
            <EventProviderId Value="Microsoft.Windows.IrisService"/>
            <EventProviderId Value="Microsoft.Windows.ApplicationModel.DesktopAppx"/>
            <EventProviderId Value="Microsoft.Windows.Security.CustomCapability"/>
            <EventProviderId Value="Microsoft.Windows.AppListBackup.AppListBackupImpl"/>
            <EventProviderId Value="Microsoft.Windows.Shell.Taskbar"/>
            <EventProviderId Value="Microsoft.Windows.AppLifeCycle.UI"/>
          </EventProviders>
        </EventCollectorId>
      </Collectors>
    </Profile>

    <Profile Id="StartResponsiveness.Verbose.File" Name="StartResponsiveness" Base="GeneralProfile.Light.File" LoggingMode="File" DetailLevel="Verbose" Description="StartResponsiveness.Verbose.File">
      <Collectors Operation="Add">
        <SystemCollectorId Value="SystemCollector_WPRSystemCollectorInFile">
          <BufferSize Value="1024"/>
          <Buffers Value="100"/>
          <SystemProviderId Value="SystemProvider_Winperf_Light"/>
        </SystemCollectorId>
        <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
          <BufferSize Value="1024" />
          <Buffers Value="3" PercentageOfTotalMemory="true"/>
          <EventProviders Operation="Add">
            <EventProviderId Value="EventProvider-Microsoft-Windows-TestExecution"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.TestExecution.WexLogger"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-XAML"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-Launcher"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Health.TestInProduction"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellCommon.StartLayout"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ForegroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ActivationManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_AppModel_Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessLifetimeManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreWindow"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Desktop.Shell.ViewManagerInterop"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.SingleViewExperience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.ExperienceHost"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.StartMenu.Experience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ErrorHandling.Fallback"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreCache"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreTransformers"/>
            <EventProviderId Value="EventProvider-WindowsInternal.Shell.UnifiedTile"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellExperienceDispatcher"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Immersive-Shell"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourceManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.HostActivityManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BackgroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BrokerInfrastructure"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-WindowsPhone-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppLifeCycle"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourcePolicy"/>
            <EventProviderId Value="EventProvider-CombaseTraceLoggingProvider"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppModel.Tiles"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Common"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Client"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Broker"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Service"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Tools"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Upgrade"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppXDeployment"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppXDeployment.Server"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Runtime"/>
            <EventProviderId Value="Microsoft-Windows-TwinAPI-Events"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.CoreApplication"/>
            <EventProviderId Value="EventProvider_Microsoft-Windows-Shell-CortanaProactive"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CortanaSearch"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CloudStore.Internal"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-AppResolver"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView-JumpViewBroker"/>
            <EventProviderId Value="Microsoft.Windows.Application.Service"/>
            <EventProviderId Value="Microsoft.Windows.Shell.Desktop.LogonFramework"/>
            <EventProviderId Value="Microsoft.Windows.Start.SharedStartModel.Cache"/>
            <EventProviderId Value="Microsoft.Windows.UI.Shell.StartUI.WinRTHelpers"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.ExperienceExtensions"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.PackManager"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.Provider"/>

            <!-- Render perf-->
            <EventProviderId Value="EventProvider-Microsoft-Windows-Dwm-Core" />
            <EventProviderId Value="EventProvider-Microsoft-Windows-DxgKrnl" />
            <EventProviderId Value="EventProvider-Microsoft-Windows-Win32k" />

            <!-- Power -->
            <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Power" />
            <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Processor-Power" />
          </EventProviders>
        </EventCollectorId>
      </Collectors>
    </Profile>

    <Profile Id="StartMemory.Verbose.File" Name="StartMemory" Base="GeneralProfile.Light.File" LoggingMode="File" DetailLevel="Verbose" Description="StartMemory.Verbose.File">
      <Collectors Operation="Add">
        <SystemCollectorId Value="SystemCollector_WPRSystemCollectorInFile">
          <BufferSize Value="1024"/>
          <Buffers Value="256"/>
          <SystemProviderId Value="SystemProvider_Winperf_Memory"/>
        </SystemCollectorId>
        <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
          <BufferSize Value="1024" />
          <Buffers Value="3" PercentageOfTotalMemory="true"/>
          <EventProviders Operation="Add">
            <EventProviderId Value="EventProvider-Microsoft-Windows-TestExecution"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.TestExecution.WexLogger"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-XAML"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-Launcher"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Health.TestInProduction"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellCommon.StartLayout"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ForegroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_ActivationManager"/>
            <EventProviderId Value="EventProvider-Microsoft_Windows_AppModel_Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessLifetimeManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-CoreWindow"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Desktop.Shell.ViewManagerInterop"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.SingleViewExperience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.ExperienceHost"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.StartMenu.Experience"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ErrorHandling.Fallback"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreCache"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.DataStoreTransformers"/>
            <EventProviderId Value="EventProvider-WindowsInternal.Shell.UnifiedTile"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ShellExperienceDispatcher"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Immersive-Shell"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourceManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.HostActivityManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BackgroundManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.BrokerInfrastructure"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ProcessStateManager"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Exec"/>
            <EventProviderId Value="EventProvider-Microsoft-WindowsPhone-CoreUIComponents"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppLifeCycle"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.ResourcePolicy"/>
            <EventProviderId Value="EventProvider-CombaseTraceLoggingProvider"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppModel.Tiles"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Common"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Client"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Broker"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Service"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Tools"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.StateRepository.Upgrade"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppXDeployment"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.AppXDeployment.Server"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-AppModel-Runtime"/>
            <EventProviderId Value="Microsoft-Windows-TwinAPI-Events"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.CoreApplication"/>
            <EventProviderId Value="EventProvider_Microsoft-Windows-Shell-CortanaProactive"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CortanaSearch"/>
            <EventProviderId Value="EventProvider_Microsoft.Windows.Shell.CloudStore.Internal"/>
            <EventProviderId Value="EventProvider-Microsoft-Windows-Shell-AppResolver"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView"/>
            <EventProviderId Value="EventProvider-Microsoft.Windows.Shell.JumpView-JumpViewBroker"/>
            <EventProviderId Value="Microsoft.Windows.Application.Service"/>
            <EventProviderId Value="Microsoft.Windows.Shell.Desktop.LogonFramework"/>
            <EventProviderId Value="Microsoft.Windows.Start.SharedStartModel.Cache"/>
            <EventProviderId Value="Microsoft.Windows.UI.Shell.StartUI.WinRTHelpers"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.ExperienceExtensions"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.PackManager"/>
            <EventProviderId Value="Microsoft.Windows.Services.Experiences.Provider"/>

            <!-- Render perf-->
            <EventProviderId Value="EventProvider-Microsoft-Windows-Dwm-Core" />
            <EventProviderId Value="EventProvider-Microsoft-Windows-DxgKrnl" />
            <EventProviderId Value="EventProvider-Microsoft-Windows-Win32k" />

            <!-- Power -->
            <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Power" />
            <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Processor-Power" />
          </EventProviders>
        </EventCollectorId>
      </Collectors>
    </Profile>

  </Profiles>
</WindowsPerformanceRecorder>
"@ 
return $startBvtXml
}

function Get-AppModelMinWprp {
$minAppModelXml = @"
<?xml version="1.0" encoding="utf-8" standalone='yes'?>

<WindowsPerformanceRecorder Version="1.0" Author="Template Team" Team="Template" Comments="Capability ETW Profiles" Company="Microsoft Corporation" Copyright="Microsoft Corporation" Tag="Template">
    <Profiles>
        <!-- Event Collectors -->
        <EventCollector Id="EventCollector_AppModel" Name="Capability Access Manager Event Collector" Private="false" ProcessPrivate="false" Secure="false" Realtime="false">
            <BufferSize Value="1024"/>
        </EventCollector>

        <!-- CapAuthz provider -->
        <EventProvider Id="Microsoft-Windows-AppModel-Runtime" Name="F1EF270A-0D32-4352-BA52-DBAB41E1D859" Level="5"/>
        <EventProvider Id="TwinUITraceLoggingProvider" Name="fa386406-8e25-47f7-a03f-413635a55dc0" Level="5"/>
        <EventProvider Id="Microsoft.Windows.AppModelRuntimeWinRT" Name="eadb8f1b-577d-4d09-8104-b61a3d9036e5" Level="5"/>
        <EventProvider Id="Microsoft.Windows.AppXDeploymentServer" Name="fe762fb1-341a-4dd4-b399-be1868b3d918" Level="5"/>
        <EventProvider Id="Microsoft.Windows.AppXDeploymentClient" Name="b89fa39d-0d71-41c6-ba55-effb40eb2098" Level="5"/>
        <EventProvider Id="Microsoft.Windows.Kernel.KernelBase" Name="05f95efe-7f75-49c7-a994-60a55cc09571" Level="5"/>
        <EventProvider Id="Microsoft.Windows.Kernel.KernelBase.Fallback" Name="b749553b-d950-5e03-6282-3145a61b1002" Level="5"/>
        <EventProvider Id="Microsoft-Windows-AppModel-Api-Runtime" Name="68df64c5-44d1-4db9-9ac1-87628a83b30d" Level="5"/>
        <EventProvider Id="EventProvider-Microsoft.Windows.ErrorHandling.Fallback" Name="bf4c9654-66d1-5720-7b51-d2ae226735ea" Level="5"/>
        <EventProvider Id="Microsoft-Windows-AppModel-Api-Runtime-TL" Name="3d658ea9-b286-4026-adab-1a5e159b29c9" Level="5"/>

        <!-- AppxPackaging and Https Providers -->
        <EventProvider Id="Microsoft-Windows-AppxPackagingOM" Name="BA723D81-0D0C-4F1E-80C8-54740F508DDF" Level="5"/>
        <EventProvider Id="Microsoft.Windows.AppxPackaging" Name="fe0ab4b4-19b6-485b-89bb-60fd931fdd56" Level="5"/>
        <EventProvider Id="Microsoft.Windows.AppModel.HttpsDataSource" Name="9b9cb5f6-76f7-5daa-cd46-536646cceb40" Level="5"/>
        <EventProvider Id="Microsoft.Windows.Appx.HttpsTransport" Name="d7c4072e-0fe3-580c-7ea5-5367644777ba" Level="5"/>

        <EventProvider Id="EventProvider_Microsoft.Windows.EnterpriseModernAppManagement" Name="0e71a49b-ca69-5999-a395-626493eb0cbd" />
        <EventProvider Id="EventProvider_Microsoft.Windows.Provisioning.Knobs.Core" Name="CF69DF80-7690-41DA-99C9-186E46860E7D" />
        <EventProvider Id="EventProvider_Microsoft.Windows.Provisioning.Knobs.Csp" Name="A9F17D57-43D6-498C-94E4-EB0E9E7E19C2" />
        <EventProvider Id="EventProvider_Microsoft.Internal.Management.SecureAssessment.Logging" Name="B16D37F8-5C56-47CA-9EE0-7575347EBE5F" />
        <EventProvider Id="EventProvider_Microsoft.Windows.Provisioning.AadjCsp" Name="724A3824-7387-449A-825E-B135F2CA4C57" />
        <EventProvider Id="EventProvider_Microsoft.Internal.Management.Autopilot.Reset" Name="F10F4696-DD8A-40F0-90BE-CD013D0DB9C7" />

        <!-- Profiles -->
        <Profile Id="AppModel.Verbose.Memory" LoggingMode="Memory" Name="AppModel" DetailLevel="Verbose" Description="AppModel category profile">
            <Collectors>
                <EventCollectorId Value="EventCollector_AppModel">
                    <EventProviders>
                        <EventProviderId Value="Microsoft-Windows-AppModel-Runtime"/>
                        <EventProviderId Value="TwinUITraceLoggingProvider"/>
                        <EventProviderId Value="Microsoft.Windows.AppModelRuntimeWinRT"/>
                        <EventProviderId Value="Microsoft.Windows.AppXDeploymentServer"/>
                        <EventProviderId Value="Microsoft.Windows.AppXDeploymentClient"/>
                        <EventProviderId Value="Microsoft.Windows.Kernel.KernelBase"/>
                        <EventProviderId Value="Microsoft.Windows.Kernel.KernelBase.Fallback"/>
                        <EventProviderId Value="Microsoft-Windows-AppModel-Api-Runtime"/>
                        <EventProviderId Value="EventProvider-Microsoft.Windows.ErrorHandling.Fallback"/>
                        <EventProviderId Value="Microsoft-Windows-AppModel-Api-Runtime-TL"/>
                        <EventProviderId Value="Microsoft-Windows-AppxPackagingOM"/>
                        <EventProviderId Value="Microsoft.Windows.AppxPackaging"/>
                        <EventProviderId Value="Microsoft.Windows.AppModel.HttpsDataSource"/>
                        <EventProviderId Value="Microsoft.Windows.Appx.HttpsTransport"/>
                        <EventProviderId Value="EventProvider_Microsoft.Windows.EnterpriseModernAppManagement" />
                        <EventProviderId Value="EventProvider_Microsoft.Windows.Provisioning.Knobs.Core" />
                        <EventProviderId Value="EventProvider_Microsoft.Windows.Provisioning.Knobs.Csp" />
                        <EventProviderId Value="EventProvider_Microsoft.Internal.Management.SecureAssessment.Logging" />
                        <EventProviderId Value="EventProvider_Microsoft.Windows.Provisioning.AadjCsp" />
                        <EventProviderId Value="EventProvider_Microsoft.Internal.Management.Autopilot.Reset" />
                    </EventProviders>
                </EventCollectorId>
            </Collectors>
        </Profile>
    </Profiles>

</WindowsPerformanceRecorder>
"@
return $minAppModelXml
}

function Get-AdexProvidersWprp {
$adexProvidersXml = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Author="Microsoft Corporation" Copyright="Microsoft Corporation" Company="Microsoft Corporation">
  <Profiles>
    <SystemCollector Id="SystemCollector" Name="NT Kernel Logger" HostGuestCorrelation="true">
        <BufferSize Value="1024"/>
        <Buffers Value="32"/>
    </SystemCollector>

    <EventCollector Id="EventCollector_WDGDEPAdex" Name="WDGDEPAdexCollector" HostGuestCorrelation="true">
      <BufferSize Value="256" />
      <Buffers Value="32" />
    </EventCollector>

    <SystemProvider Id="SystemProviderVerbose">
      <Keywords>
        <Keyword Value="ProcessThread"/>
        <Keyword Value="Loader"/>
      </Keywords>
    </SystemProvider>

    <!-- <EventProvider Id="Microsoft.Windows.AppXDeploymentServer" Name="fe762fb1-341a-4dd4-b399-be1868b3d918" Stack="true"> -->
    <EventProvider Id="Microsoft.Windows.AppXDeploymentServer" Name="fe762fb1-341a-4dd4-b399-be1868b3d918">
      <StackEventNameFilters FilterIn="true">
        <EventName Value="Failure"/>
      </StackEventNameFilters>
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

            <!-- Activation Execution -->
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

            <!-- Watson Error Reporting -->
            <EventProvider Id="Microsoft.Windows.FaultReporting" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>
            <EventProvider Id="Microsoft.Windows.WindowsErrorReporting" Name="CC79CF77-70D9-4082-9B52-23F3A3E92FE4"/>
            <EventProvider Id="Microsoft.Windows.HangReporting" Name="3E0D88DE-AE5C-438A-BB1C-C2E627F8AECB"/>
          </EventProviders>
        </EventCollectorId>
      </Collectors>
    </Profile>
  </Profiles>
</WindowsPerformanceRecorder>
"@
return $adexProvidersXml
}

function Invoke-UnicodeTool {
    param (
        [string]$ToolString
    )
    # Switch output encoding to unicode and then back to the default for tools
    # that output to the command line as unicode.
    $oldEncoding = [console]::OutputEncoding
    [console]::OutputEncoding = [Text.Encoding]::Unicode
    Invoke-Expression $ToolString
    [console]::OutputEncoding = $oldEncoding
}

function Checkpoint-UTMData {
    $utmLogLocation = (Join-Path $LogsDestinationPath "UnifiedTileModel");

    mkdir "$utmLogLocation\ShellExperienceHost" | Out-Null
    mkdir "$utmLogLocation\StartMenuExperienceHost" | Out-Null

    # TODO - Each app package will have a distinct cache file.  For RS2, the file was UnifiedTileCache.dat.  For RS3 and later it is StartUnifiedTileModelCache.dat.  SMEH only has the latter.
    Copy-Item "$env:LocalAppData\Packages\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy\TempState\StartUnifiedTileModelCache*" "$utmLogLocation\ShellExperienceHost" -Force -ErrorAction SilentlyContinue
    Copy-Item "$env:LocalAppData\Packages\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy\TempState\UnifiedTileCache*" "$utmLogLocation\ShellExperienceHost" -Force -ErrorAction SilentlyContinue
    Copy-Item "$env:LocalAppData\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\TempState\StartUnifiedTileModelCache*" "$utmLogLocation\StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue

    [string]$cacheDumpToolPath = Join-Path (Join-Path $env:windir "system32") "datastorecachedumptool.exe";
    if (Test-Path -PathType Leaf $cacheDumpToolPath) {
        # The cache dump tool is present in the OS image.  Use it.  If the cache file exists then dump it.  Regardless of whether it exists also take
        # a live dump.
        if (Test-Path -PathType Leaf "$utmLogLocation\ShellExperienceHost\StartUnifiedTileModelCache.dat") {
            Invoke-UnicodeTool("$cacheDumpToolPath -f $utmLogLocation\ShellExperienceHost\StartUnifiedTileModelCache.dat") | Out-File "$utmLogLocation\ShellExperienceHost\StartUnifiedTileModelCacheDump.log"
        }
        elseif (Test-Path -PathType Leaf "$utmLogLocation\ShellExperienceHost\UnifiedTileCache.dat") {
            Invoke-UnicodeTool("$cacheDumpToolPath -f $utmLogLocation\ShellExperienceHost\UnifiedTileCache.dat") | Out-File "$utmLogLocation\ShellExperienceHost\UnifiedTileCacheDump.log"
        }

        if (Test-Path -PathType Leaf "$utmLogLocation\StartMenuExperienceHost\StartUnifiedTileModelCache.dat") {
            Invoke-UnicodeTool("$cacheDumpToolPath -f $utmLogLocation\StartMenuExperienceHost\StartUnifiedTileModelCache.dat") | Out-File "$utmLogLocation\StartMenuExperienceHost\StartUnifiedTileModelCacheDump.log"
        }

        Invoke-UnicodeTool("$cacheDumpToolPath -l") | Out-File "$utmLogLocation\LiveUTMDump.log"
    }
}

function Stop-WprBootTracing {
    param (
        [string]$LogsDestinationPath
    )

    $appModelMinTraceStopped = $false
    $adexProvidersTraceStopped = $false
    $startBvtTraceStopped = $false
    try {
        $etlPath = (Join-Path -Path $LogsDestinationPath -ChildPath 'AppModelLogs.etl')
        Write-Host "[$(Get-Timestamp)] Ending WPR instance name: AppModelMin - $etlPath"
        wpr -boottrace -stopboot $etlPath -instancename "AppModelMin"
        $appModelMinTraceStopped = $true
    } catch {
        if(!$appModelMinTraceStopped) {
            Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: AppModelMin."
        }
    }
    
    try {
        $etlPath = (Join-Path -Path $LogsDestinationPath -ChildPath 'AdexProvidersLogs.etl')
        Write-Host "[$(Get-Timestamp)] Ending WPR instance name: AdexProviders - $etlPath"
        wpr -boottrace -stopboot $etlPath -instancename "AdexProviders"
        $adexProvidersTraceStopped = $true
    } catch {
        if(!$adexProvidersTraceStopped) {
            Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: AdexProviders."
        }
    }
    
    try {
        $etlPath = (Join-Path -Path $LogsDestinationPath -ChildPath 'StartBvtLogs.etl')
        Write-Host "[$(Get-Timestamp)] Ending WPR instance name: StartBvt - $etlPath"
        wpr -boottrace -stopboot $etlPath -instancename "StartBvt"
        $startBvtTraceStopped = $true
    } catch {
        if(!$startBvtTraceStopped) {
            Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: StartBvt."
        }
    }
    
    $tracingStopped = $appModelMinTraceStopped -and $adexProvidersTraceStopped -and $startBvtTraceStopped
    if($tracingStopped) {
        Write-Host "[$(Get-Timestamp)] Boot tracing stopped. Please zip and share the ETL files from $LogsDestinationPath"
    } else {
        Write-Error "[$(Get-Timestamp)] Boot tracing failed to stop."
    }
}

function Trace-WprEvents {
    param (
        [string]$LogsDestinationPath
    )

    #Start tracelogging
    $appModelMinTraceStarted = $false
    $adexProvidersTraceStarted = $false
    $startBvtTraceStarted = $false
    $procmonStarted = $false

    try {
        $appModelMinFile = (Join-Path -Path $LogsDestinationPath -ChildPath 'AppModelMin.wprp')
        Get-AppModelMinWprp | Out-File -FilePath $appModelMinFile -Encoding UTF8

        Write-Host "[$(Get-Timestamp)] Starting WPR instance name: AppModelMin (wprp: $appModelMinFile)"
        if ($StartBoot -eq $true) {
            wpr -boottrace -addboot $appModelMinFile -instancename "AppModelMin"
        } else {
            wpr -start $appModelMinFile -instancename "AppModelMin"
        }
        $appModelMinTraceStarted = $true
    } catch {
        if(!$appModelMinTraceStarted) {
            Write-Error "[$(Get-Timestamp)] Failed to start WPR instance name: AppModelMin."
        }
    }
    
    try {
        $adexProvidersFile = (Join-Path -Path $LogsDestinationPath -ChildPath 'adexproviders.wprp')
        Get-AdexProvidersWprp | Out-File -FilePath $adexProvidersFile -Encoding UTF8

        Write-Host "[$(Get-Timestamp)] Starting WPR instance name: AdexProviders (wprp: $adexProvidersFile)"
        if ($StartBoot -eq $true) {
            wpr -boottrace -addboot $adexProvidersFile -filemode -instancename "AdexProviders"
        } else {
            wpr -start $adexProvidersFile -filemode -instancename "AdexProviders"
        }
        $adexProvidersTraceStarted = $true
    } catch {
        if(!$adexProvidersTraceStarted) {
            Write-Error "[$(Get-Timestamp)] Failed to start WPR instance name: AdexProviders."
        }
    }
    
    try {
        $startBvtFile = (Join-Path -Path $LogsDestinationPath -ChildPath 'StartBvt.wprp')
        Get-StartBvtWprp | Out-File -FilePath $startBvtFile -Encoding UTF8

        Write-Host "[$(Get-Timestamp)] Starting WPR instance name: StartBvt (wprp: $startBvtFile)"
        if ($StartBoot -eq $true) {
            wpr -boottrace -addboot $startBvtFile -filemode -instancename "StartBvt"
        } else {
            wpr -start $startBvtFile -filemode -instancename "StartBvt"
        }
        $startBvtTraceStarted = $true
    } catch {
        if(!$startBvtTraceStarted) {
            Write-Error "[$(Get-Timestamp)] Failed to start WPR instance name: StartBvt."
        }
    }
    
    try {
        if($ProcmonPath.Length -gt 0) {
            Write-Host "procmon path length over 0"
            $procmonBackingFilePath = ($LogsDestinationPath + '\ProcmonLogs.pml')
            $procmonArgs = "/AcceptEULA /Quiet /Minimized /BackingFile $procmonBackingFilePath"
            Write-Host "[$(Get-Timestamp)] Starting Procmon trace to file"
            Start-Process -FilePath $ProcmonPath -ArgumentList $procmonArgs -Passthru
            $procmonStarted = $true
        }
    } catch {
        if(!$procmonStarted) {
            Write-Error "[$(Get-Timestamp)] Failed to start Procmon."
        }
    }

    $tracingStarted = $appModelMinTraceStarted -or $adexProvidersTraceStarted -or $startBvtTraceStarted -or $procmonStarted
    if($tracingStarted) {
        if ($StartBoot -eq $true) {
            Write-Host "[$(Get-Timestamp)] Boot tracing enabled. Restart the machine to trigger trace collection. After doing the repro, run '.\GetDeploymentLogsWithOptions.ps1 -StopBoot'."
            Exit 0
        } else {
            Write-Host "[$(Get-Timestamp)] Live Tracing Started. Go ahead and reproduce your problem. Press [Enter] when done."
            [void][System.Console]::ReadLine()
        }
    } else {
        Write-Error "[$(Get-Timestamp)] Live Tracing failed to start."
    }

    try {
        if($procmonStarted) {
            Write-Host "[$(Get-Timestamp)] Ending Procmon trace to file"
            Start-Process -FilePath $ProcmonPath -ArgumentList "/Terminate" -Wait
        }
    } catch {
        Write-Error "[$(Get-Timestamp)] Failed to terminate Procmon."
    }
    try {
        if($appModelMinTraceStarted) {
            Write-Host "[$(Get-Timestamp)] Ending WPR instance name: AppModelMin"
            if ($StopBoot -eq $true) {
                wpr -boottrace -stopboot ($LogsDestinationPath + '\AppModelLogs.etl') -instancename "AppModelMin"
            } else {
                wpr -stop ($LogsDestinationPath + '\AppModelLogs.etl') -instancename "AppModelMin"
            }
        }
    } catch {
        Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: AppModelMin."
    }
    try {
        if($adexProvidersTraceStarted) {
            Write-Host "[$(Get-Timestamp)] Ending WPR instance name: AdexProviders"
            if ($StopBoot -eq $true) {
                wpr -boottrace -stopboot ($LogsDestinationPath + '\AdexLogs.etl') -instancename "AdexProviders"
            } else {
                wpr -stop ($LogsDestinationPath + '\AdexLogs.etl') -instancename "AdexProviders"
            }
        }
    } catch {
        Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: AdexProviders"
    }
    try {
        if($startBvtTraceStarted) {
            Write-Host "[$(Get-Timestamp)] Ending WPR instance name: StartBvt"
            if ($StopBoot -eq $true) {
                wpr -boottrace -stopboot ($LogsDestinationPath + '\StartBvt.etl') -instancename "StartBvt"
            } else {
                wpr -stop ($LogsDestinationPath + '\StartBvt.etl') -instancename "StartBvt"
            }
        }
    } catch {
        Write-Error "[$(Get-Timestamp)] Failed to end WPR instance name: StartBvt"
    }
}

function Publish-StaticData {
    param (
        [string]$LogsDestinationPath
    )

    Write-Host "[$(Get-Timestamp)] Collecting static data..."

    $ComputerInfo = $(Get-ComputerInfo)
    $ComputerInfo.OsHotFixes  | Out-File -Append ($LogsDestinationPath + '\OSVersion.txt')
    $ComputerInfo.WindowsBuildLabEx | Out-File -Append ($LogsDestinationPath + '\OSVersion.txt')

    fltmc filters > ($LogsDestinationPath + '\FltmcFilters.txt')
    $doSvcFile = $LogsDestinationPath + '\dosvc.log'
    Get-DeliveryOptimizationLog | Set-Content $doSvcFile

    "1.0.8"  > ($LogsDestinationPath + '\ScriptVersion.txt')
}

function Checkpoint-PersistedData {
    param (
        [string]$LogsDestinationPath
    )
Write-Host 'Creating Destination Folder and Gathering Logs ' $LogsDestinationPath
Write-Host "[$(Get-Timestamp)] Collecting persisted log data..."
  

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
            (("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModel"), ($RegExportsDestinationPath + '\AppModel.reg')),
            (("HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"), ($RegExportsDestinationPath + '\Minirepository.reg')),
            (("HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\Terminal Services"), ($RegExportsDestinationPath + '\PolicyTerminalServices.reg')),
            (("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server"), ($RegExportsDestinationPath + '\CurrentControlSetTerminalServer.reg'))
        )

Write-Progress -Activity 'Collecting event logs' -Id 10041

$EventLogsFolderPath = ($LogsDestinationPath + '\EventLogs\')
New-Item -ItemType Directory -Force -Path $EventLogsFolderPath > $null

# Copy Event Logs
foreach ($EventLogFile in $SystemEventLogFileList)
{
    $EventLogFilePath = ($SystemEventLogsPath + $EventLogFile)
    Copy-Item -Path $EventLogFilePath -Destination $EventLogsFolderPath -Force -ErrorAction SilentlyContinue
}

foreach ($SDPair in $SourceDestinationPairs)
{
    New-Item -ItemType Directory -Force -Path $SDPair[1] > $null
    Copy-Item -Path $SDPair[0] -Destination $SDPair[1] -Recurse -Force -ErrorAction SilentlyContinue > $null
}

foreach ($RegistrySDPair in $RegistrySourceDestinationPairs)
{
    reg export $RegistrySDPair[0] $RegistrySDPair[1] /y *> $null
}

$AppDataPath = $env:LOCALAPPDATA + '\Packages'
$WindowsAppPath = $env:ProgramFiles + '\WindowsApps'
$AppRepositoryPath = $env:ProgramData + '\Microsoft\Windows\AppRepository'

Get-AppxPackage -AllUsers > ($LogsDestinationPath + '\GetAppxPackageAllUsersOutput.txt')
Get-AppxPackage > ($LogsDestinationPath + '\GetAppxPackageCurrentUserOutput.txt')
([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value  > ($LogsDestinationPath + '\CurrentUserSid.txt')
Get-ChildItem -Path $AppDataPath -Recurse -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\AppDataFolderList.txt')
Get-ChildItem -Path $WindowsAppPath -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\WindowsAppFolderList.txt')
Get-ChildItem -Path $AppRepositoryPath -Force -ErrorAction SilentlyContinue > ($LogsDestinationPath + '\AppRepositoryFileList.txt')

Write-Progress -Activity 'Collecting ACLs' -Id 10041
}

function Collect-AfterTracingData {
    param (
        [string]$LogsDestinationPath,
        [bool]$TracingEnabled
    )
    Write-Host 'Collecting data checkpoint after tracing ends: '
    if ($TracingEnabled) {
        $LogsDestinationSubPath = $LogsDestinationPath + '\AfterTracing'
    } else {
        $LogsDestinationSubPath = $LogsDestinationPath
    }
    
    New-Item -ItemType Directory -Force -Path $LogsDestinationSubPath > $null
    Checkpoint-PersistedData($LogsDestinationSubPath)

    Publish-StaticData($LogsDestinationPath)

    Write-Progress -Activity 'Creating Zip Archive' -Id 10042
    Add-Type -Assembly "System.IO.Compression.FileSystem";
    [System.IO.Compression.ZipFile]::CreateFromDirectory($LogsDestinationPath, $CabPath);

    Write-Progress -Activity 'Done' -Completed -Id 10042
    Write-Warning "Note: Below Zip file contains system, app and user information useful for diagnosing Application Installation Issues."
    Write-Host 'Please upload zip and share a link : '
    Write-Host $CabPath
}

# ==================================================================================================
# Main
# ==================================================================================================

if ($PSBoundParameters.ContainsKey('CancelBoot') -and $CancelBoot) {
    Write-Host "Cancelling ETW boot tracing"
    wpr.exe -cancelboot
    Exit 0
}

if (($PSBoundParameters.ContainsKey('StartBoot') -and $StartBoot) -or ($PSBoundParameters.ContainsKey('StopBoot') -and $StopBoot)) {
    $dateString = (Get-Date).ToString('MM-dd-yyyy')
    $LogsFolderName = 'AppxLogs-' + $dateString
} else {
    $LogsFolderName = 'AppxLogs-' + (get-date -uformat %s)
}

$LogsDestinationPath = Join-Path -Path $env:TEMP -ChildPath $LogsFolderName
$CabPath = $LogsDestinationPath + '.zip'

# Check if LogsDestinationPath exists, create if not
if (-not (Test-Path -Path $LogsDestinationPath)) {
    New-Item -ItemType Directory -Force -Path $LogsDestinationPath > $null
}

# Validation: StartBoot requires EnableTracing
if ($PSBoundParameters.ContainsKey('StartBoot') -and $StartBoot) {
    if (-not ($PSBoundParameters.ContainsKey('EnableTracing') -and $EnableTracing)) {
        Write-Error "The -StartBoot switch can only be used together with -EnableTracing."
        exit 1
    }
}

if ($PSBoundParameters.ContainsKey('StopBoot') -and $StopBoot) {
    Stop-WprBootTracing -LogsDestinationPath $LogsDestinationPath
    Collect-AfterTracingData -LogsDestinationPath $LogsDestinationPath -TracingEnabled $true
    Exit 0
}

Get-ChildItem -Path $WindowsAppPath | Get-Acl | Format-List > ($LogsDestinationPath + '\WindowsAppsAcls.txt')

$systemTempPath = [System.Environment]::GetEnvironmentVariable('TEMP', 'Machine')
Get-Acl $systemTempPath | Format-List > ($LogsDestinationPath + '\TempAcls.txt')

$systemAppDataReg = "HKCU:Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
Get-Acl $systemAppDataReg | Format-List > ($LogsDestinationPath + '\SystemAppDataAcls.txt')

if($TargetPackageFamilyName.Length -gt 0) {

  $targetPackageFamilyNameParts = $TargetPackageFamilyName -split '_'
  if ($targetPackageFamilyNameParts.Length -eq 2) {
    $TargetPackageName = $targetPackageFamilyNameParts[0]
    $TargetPackagePublisherHash = $targetPackageFamilyNameParts[1]

    $TargetPackageFamilyNameAppPath = $env:ProgramFiles + '\WindowsApps\' + $TargetPackageName + '_*_' + $TargetPackagePublisherHash + '\*.exe'
    Get-Acl $TargetPackageFamilyNameAppPath | Format-List > ($LogsDestinationPath + '\' + $TargetPackageFamilyName + '.ExeAcls.txt')
  }

  $targetPackageFamilyAppDataReg = "HKCU:Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\" + $TargetPackageFamilyName
  Get-Acl -Path $targetPackageFamilyAppDataReg | Format-List > ($LogsDestinationPath + '\SystemAppData.' + $TargetPackageFamilyName + '.Acls.txt')

  reg export ("HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$TargetPackageFamilyName") ($RegExportsDestinationPath + '\' + $TargetPackageFamilyName + '.HKCUSystemAppData.reg') /y *> $null
}

Write-Progress -Activity 'Collecting Start data' -Id 10041
Checkpoint-UTMData
# Retrieve the REG_BINARY value from the registry
$binaryValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" -Name "Favorites"
# Extract the binary data
$binaryData = $binaryValue.Favorites
# Convert the binary data to an ASCII string
$asciiString = [System.Text.Encoding]::ASCII.GetString($binaryData)
# Output the ASCII string
$asciiString  > ($LogsDestinationPath + '\TaskbandFavorites.txt')

Write-Progress -Activity 'Done' -Completed -Id 10041

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

$tracingExplicitlySet = $false
$tracingEnabled = $false
if ($PSBoundParameters.ContainsKey('EnableTracing')) {
    $tracingExplicitlySet = $true
    if ($EnableTracing) {
        $tracingEnabled = $true
    }
}


$skipBeforeCheckpointSet = $false
if ($PSBoundParameters.ContainsKey('SkipBeforeCheckpoint')) {
    if ($SkipBeforeCheckpoint) {
        $skipBeforeCheckpointSet = $true
    }
}

if (!($tracingExplicitlySet)) {
  # Pause and wait for the user to choose log collection style
  Write-Host "[$(Get-Timestamp)] Would you like to reproduce your problem with tracing enabled? Press [Y] to start tracing, [N] to continue with immediate log collection..."
  # Read the user's input
  $userInput = Read-KeyPress
  if ($userInput -eq 'Y') {
      $tracingEnabled = $true
  }
}

if ($tracingEnabled) {
    if (!$skipBeforeCheckpointSet) {
        # Collect static data before collecting tracing to allow before\after data comparison.
        Write-Host 'Collecting data checkpoint before tracing begins: '
        $LogsDestinationSubPath = $LogsDestinationPath + '\BeforeTracing'
        New-Item -ItemType Directory -Force -Path $LogsDestinationSubPath > $null
        Checkpoint-PersistedData -$LogsDestinationPath $LogsDestinationSubPath
    }

  Trace-WprEvents -LogsDestinationPath $LogsDestinationPath
}

# Collect additional data after tracing
Collect-AfterTracingData -LogsDestinationPath $LogsDestinationPath -TracingEnabled $tracingEnabled

Pause
