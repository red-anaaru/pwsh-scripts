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
.\CaptureTeamsTrace.ps1 -Start
<do your repro steps>
.\CaptureTeamsTrace.ps1 -Stop <"C:\path\to\save">
#>

# PowerShell script to start and then stop and save a running trace.
[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    [Parameter(ParameterSetName="Start")]
    [switch]$Start,
    [Parameter(ParameterSetName="Start")]
    [switch]$IncludeDisk = $false,
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

$diskTraces = if ($IncludeDisk) {
    '
                <!-- Disk -->
                <Keyword Value="DiskIO"/>
                <Keyword Value="FileIO"/>
                <Keyword Value="HardFaults"/>'
} else {
    ''
}

$wprpContents = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="1.0" Comments="" Company="Microsoft Corporation" Copyright="Microsoft Corporation">
    <Profiles>
        <SystemProvider Id="SystemProvider_Light">
            <Keywords>
                <!-- CPU -->
                <Keyword Value="ProcessThread"/>
                <Keyword Value="Loader"/>
                <Keyword Value="Power"/>
                <Keyword Value="CSwitch"/>
                <Keyword Value="ReadyThread"/>
                <Keyword Value="SampledProfile"/>
                <Keyword Value="DPC"/>
                <Keyword Value="Interrupt"/>
                <Keyword Value="IdleStates"/>

                <!-- Memory -->
                <Keyword Value="MemoryInfo"/>
                <Keyword Value="MemoryInfoWS"/>
                $diskTraces
            </Keywords>
            <Stacks>
                <Stack Value="CSwitch"/>
                <Stack Value="ReadyThread"/>
                <Stack Value="SampledProfile"/>
            </Stacks>
        </SystemProvider>

        <!-- Crash reporting events -->
        <EventProvider Id="EventProvider-Microsoft-Windows-WindowsErrorReporting" Name="cc79cf77-70d9-4082-9b52-23f3a3e92fe4"/>
        <EventProvider Id="EventProvider-Microsoft.Windows.FaultReportingTracingGuid" Name="1377561D-9312-452C-AD13-C4A1C9C906E0"/>

        <!-- Process, thread, and image load events -->
        <EventProvider Id="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" Name="22fb2cd6-0e7b-422b-a0c7-2fad1fd0e716" NonPagedMemory="true" Stack="true" Level="0" EventKey="true">
            <Keywords>
                <Keyword Value="0x190" />
            </Keywords>
        </EventProvider>

        <!-- WV2 events. Edge providers are included to support tracing when using pre-release runtimes. -->
        <EventProvider Id="Edge" Name="3A5F2396-5C8F-4F1F-9B67-6CCA6C990E61" Level="5">
            <Keywords>
                <Keyword Value="0x10000000202F"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Canary" Name="C56B8664-45C5-4E65-B3C7-A8D6BD3F2E67" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Dev" Name="D30B5C9F-B58F-4DC9-AFAF-134405D72107" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_Beta" Name="BD089BAA-4E52-4794-A887-9E96868570D2" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Edge_WebView" Name="E16EC3D2-BB0F-4E8F-BDB8-DE0BEA82DC3D" Level="5">
            <Keywords>
                <Keyword Value="0x3F0000054404"/>
            </Keywords>
        </EventProvider>
        <EventProvider Id="Provider_V8js" Name="57277741-3638-4A4B-BDBA-0AC6E45DA56C" Level="5" Stack="true" />

        <!-- T2 events. -->
        <EventProvider Id="EventProvider_Teams" Name="f6d27019-d64d-5e73-8422-d0abbb625d94" />

        <!-- Misc. Windows input events -->
        <EventProvider Id="Win32k_Events" Name="8c416c79-d49b-4f01-a467-e56d3aa8234c" NonPagedMemory="true">
            <Keywords>
                <Keyword      Value="0x2005A6A000"/>
                <!-- <Keyword       Value="0x2000"/> Focus -->
                <!-- <Keyword       Value="0x8000"/> win32Power -->
                <!-- <Keyword      Value="0x20000"/> UserActivity -->
                <!-- <Keyword      Value="0x40000"/> UIUnresponsiveness -->
                <!-- <Keyword     Value="0x200000"/> ThreadInfo -->
                <!-- <Keyword     Value="0x800000"/> MessagePumpInternalAndInput -->
                <!-- <Keyword    Value="0x1000000"/> TouchInput -->
                <!-- <Keyword   Value="0x04000000"/> PointerInput -->
                <!-- <Keyword Value="0x2000000000"/> UserCrit telemetry -->
            </Keywords>
            <CaptureStateOnStart>
                <Keyword      Value="0xC0000"/>
                <!-- <Keyword Value="0x40000"/> UIUnresponsiveness -->
                <!-- <Keyword Value="0x80000"/> ThreadRundown -->
            </CaptureStateOnStart>
            <CaptureStateOnSave>
                <Keyword      Value="0xC0000"/>
                <!-- <Keyword Value="0x40000"/> UIUnresponsiveness -->
                <!-- <Keyword Value="0x80000"/> ThreadRundown -->
            </CaptureStateOnSave>
        </EventProvider>

        <Profile Id="Teams.General.Verbose.File" Name="Teams.General" LoggingMode="File" DetailLevel="Verbose" Description="Teams.General" Default="true">
            <Collectors Operation="Add">
                <SystemCollectorId Value="SystemCollector_WPRSystemCollectorInFile">
                    <BufferSize Value="1024"/>
                    <Buffers Value="100"/>
                    <SystemProviderId Value="SystemProvider_Light" />
                </SystemCollectorId>
                <EventCollectorId Value="EventCollector_WPREventCollectorInFile">
                    <BufferSize Value="1024" />
                    <Buffers Value="3" PercentageOfTotalMemory="true"/>
                    <EventProviders Operation="Add">
                        <EventProviderId Value="EventProvider-Microsoft-Windows-WindowsErrorReporting"/>
                        <EventProviderId Value="EventProvider-Microsoft.Windows.FaultReportingTracingGuid"/>
                        <EventProviderId Value="EventProvider_Microsoft-Windows-Kernel-Process_16_0_68_1_0_0" />
                        <EventProviderId Value="Edge" />
                        <EventProviderId Value="Edge_Canary" />
                        <EventProviderId Value="Edge_Dev" />
                        <EventProviderId Value="Edge_Beta" />
                        <EventProviderId Value="Edge_WebView" />
                        <EventProviderId Value="Provider_V8js" />
                        <EventProviderId Value="EventProvider_Teams" />
                        <EventProviderId Value="Win32k_Events" />
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

$wprpPath = Join-Path -Path $tempPath -ChildPath ("teams_" + $currentDateTime + ".wprp")
Set-Content -Path $wprpPath -Value $wprpContents

if($PSCmdlet.ParameterSetName -eq "Show") {
    Write-Host "WPRP file: $wprpPath"
    Write-Host "To collect trace: wpr.exe -start $wprpPath -filemode"
    Write-Host "To stop trace: wpr.exe -stop teams_" + $currentDateTime + ".etl"
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
    $etlPath = Join-Path -Path $out -ChildPath ("teams_" + $currentDateTime + ".etl")
    Write-Host "Stopping ETW tracing"
    wpr.exe -stop $etlPath
}
