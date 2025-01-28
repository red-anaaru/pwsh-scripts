# Define Advapi32 functions
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Advapi32 {
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, ref IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool GetTokenInformation(IntPtr TokenHandle, int TokenInformationClass, byte[] TokenInformation, int TokenInformationLength, ref int ReturnLength);
}
"@

# Function to get token information
function Get-TokenInformation {
    param (
        [int]$ProcessId
    )

    # Open the process with required access
    $processHandle = [System.Diagnostics.Process]::GetProcessById($ProcessId).Handle

    # Open the process token
    $tokenHandle = New-Object System.IntPtr
    $openProcessToken = [Advapi32]::OpenProcessToken($processHandle, 0x0008, [ref]$tokenHandle)

    if ($openProcessToken) {
        # Get token user information
        $tokenUser = New-Object byte[] 256
        $returnLength = [ref]0
        [Advapi32]::GetTokenInformation($tokenHandle, 1, $tokenUser, $tokenUser.Length, $returnLength)

        $sid = New-Object System.Security.Principal.SecurityIdentifier([BitConverter]::ToString($tokenUser, 8, 28).Replace("-", ""))
        $user = $sid.Translate([System.Security.Principal.NTAccount])

        # Get token owner information
        $tokenOwner = New-Object byte[] 256
        [Advapi32]::GetTokenInformation($tokenHandle, 4, $tokenOwner, $tokenOwner.Length, $returnLength)

        $ownerSid = New-Object System.Security.Principal.SecurityIdentifier([BitConverter]::ToString($tokenOwner, 8, 28).Replace("-", ""))
        $owner = $ownerSid.Translate([System.Security.Principal.NTAccount])

        # Get token integrity level
        $tokenIntegrityLevel = New-Object byte[] 256
        [Advapi32]::GetTokenInformation($tokenHandle, 25, $tokenIntegrityLevel, $tokenIntegrityLevel.Length, $returnLength)

        $integrityLevelSid = New-Object System.Security.Principal.SecurityIdentifier([BitConverter]::ToString($tokenIntegrityLevel, 8, 28).Replace("-", ""))
        $integrityLevel = $integrityLevelSid.Translate([System.Security.Principal.NTAccount])

        # Get token privileges
        $tokenPrivileges = New-Object byte[] 256
        [Advapi32]::GetTokenInformation($tokenHandle, 3, $tokenPrivileges, $tokenPrivileges.Length, $returnLength)

        $privileges = [BitConverter]::ToString($tokenPrivileges, 8, 28).Replace("-", "")

        # Output token information
        [PSCustomObject]@{
            ProcessId       = $ProcessId
            User            = $user
            Owner           = $owner
            IntegrityLevel  = $integrityLevel
            Privileges      = $privileges
        }
    } else {
        Write-Warning "Failed to open process token for ProcessId: $ProcessId"
    }
}

# Function to get the main ms-teams.exe process
function Get-TeamsMainAppProcess {
    $teamsProcesses = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
    foreach ($process in $teamsProcesses) {
        $commandLine = (Get-WmiObject -Query "SELECT CommandLine FROM Win32_Process WHERE ProcessId = $($process.Id)").CommandLine
        if ($commandLine -notmatch '--process_type=native_module') {
            return $process
        }
    }
    return $null
}

# Function to get details of a browser process
function Get-BrowserProcessDetails {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.ManagementObject]$Process
    )
    $commandLine = (Get-WmiObject -Query "SELECT CommandLine FROM Win32_Process WHERE ProcessId = $($Process.ProcessId)").CommandLine
    $type = if ($commandLine -match '--embedded-browser-webview=1') { 
        "browser" 
    } else { 
        "Unknown" 
    }
    if ($type) {
        return [PSCustomObject]@{
            PID         = $Process.ProcessId
            Name        = $type
            CommandLine = $commandLine
        }
    } else {
        return $null
    }
}

# Function to get child processes of a browser process
function Get-BrowserChildProcesses {
    param (
        [Parameter(Mandatory = $true)]
        [int]$browserProcessProcessId
    )
    $processDetailsList = @()
    $childProcesses = Get-WmiObject -Query "SELECT * FROM Win32_Process WHERE ParentProcessId = $($browserProcessProcessId) AND Name = 'msedgewebview2.exe'"
    foreach ($process in $childProcesses) {
        $commandLine = (Get-WmiObject -Query "SELECT CommandLine FROM Win32_Process WHERE ProcessId = $($process.ProcessId)").CommandLine
        $type = if ($commandLine -match '--type=([^ ]+)') { 
            $matches[1] 
        } else { 
            "Unknown" 
        }
        if ($type) {
            Write-Host "Found $type process [PID: $($process.ProcessId)]"
            $processDetailsList += [PSCustomObject]@{
                PID         = $Process.ProcessId
                Name        = $type
                CommandLine = $commandLine
            }
        } else {
            return $null
        }
    }
    return $processDetailsList
}

function Get-MSEdgeWebView2ChildProcesses {
    $teamsProcess = Get-TeamsMainAppProcess
    if ($teamsProcess) {
        $childProcesses = Get-WmiObject -Query "SELECT * FROM Win32_Process WHERE ParentProcessId = $($teamsProcess.Id) AND Name = 'msedgewebview2.exe'"
        $processDetailsList = @()
        foreach ($process in $childProcesses) {
            $processDetails = Get-BrowserProcessDetails -Process $process
            if ($processDetails) {
                $processDetailsList += $processDetails
                if ($processDetails.Name -eq "browser") {
                    Write-Host "Found browser process with PID $($processDetails.PID). Getting child processes..."
                    $browserChildProcesses = Get-BrowserChildProcesses -browserProcessProcessId $processDetails.PID
                    if ($browserChildProcesses) {
                        $processDetailsList += $browserChildProcesses
                    }
                }
            }
        }
        return $processDetailsList
    } else {
        Write-Host "ms-teams.exe process not found."
    }
}

# Get msedgewebview2.exe child processes of ms-teams.exe and output the details
$msEdgeWebView2ChildProcesses = Get-MSEdgeWebView2ChildProcesses
if ($msEdgeWebView2ChildProcesses) {
    $msEdgeWebView2ChildProcesses | Format-Table -AutoSize
}

# Iterate through msedgewebview2.exe child processes and call Get-SIDDetails
$sidDetailsList = @()
foreach ($process in $msEdgeWebView2ChildProcesses) {
    $processInfo = Get-WmiObject -Query "SELECT * FROM Win32_Process WHERE ProcessId = $($process.PID)"
    if ($processInfo) {
        $tokenInfo = Get-TokenInformation -ProcessId $process.PID
        if ($tokenInfo) {
            $sidDetailsList += [PSCustomObject]@{
                SID   = $tokenInfo.User.Value
                Name  = $tokenInfo.User
                Flags = $tokenInfo.Owner
            }
        }
    }
}

# Output the SID details
$sidDetailsList | Format-Table -AutoSize
