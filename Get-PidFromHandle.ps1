param (
    [Parameter(Mandatory = $true)]
    [uint]$processHandle
)

if (-not $processHandle) {
  $processHandle = Read-Host "Enter the process handle"
}

Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class Kernel32 {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint GetProcessId(IntPtr hProcess);
    }
"@

# Invoke the GetProcessId function
$processId = [Kernel32]::GetProcessId($processHandle)

# Output the process ID
Write-Output "The process ID is: $processId"
