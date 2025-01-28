# Function to get named pipes created by a specific process
function Get-NamedPipesByProcess {
    param (
        [string]$ProcessName
    )

    # Get the process ID (PID) of the specified process
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

    if ($process) {
        $processId = $process.Id

        # Get list of all named pipes
        $pipes = Get-ChildItem -Path \\.\pipe\ | Select-Object -ExpandProperty FullName

        # Initialize an array to store the results
        $results = @()

        # Add-Type to use kernel32.dll functions
        Add-Type @"
        using System;
        using System.Runtime.InteropServices;

        public class Kernel32 {
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr CreateFile(
                string lpFileName,
                uint dwDesiredAccess,
                uint dwShareMode,
                IntPtr lpSecurityAttributes,
                uint dwCreationDisposition,
                uint dwFlagsAndAttributes,
                IntPtr hTemplateFile);

            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool GetNamedPipeServerProcessId(IntPtr Pipe, out int ServerProcessId);

            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool CloseHandle(IntPtr hObject);
        }
"@

        # Iterate through each named pipe
        foreach ($pipe in $pipes) {
            # Open a handle to the named pipe
            $hPipe = [Kernel32]::CreateFile($pipe, 0x80000000, 0, [IntPtr]::Zero, 3, 0x80, [IntPtr]::Zero)

            if ($hPipe -ne [IntPtr]::Zero) {
                # Get the owning PID of the pipe
                $pipeOwner = 0
                $pipeOwnerFound = [Kernel32]::GetNamedPipeServerProcessId($hPipe, [ref]$pipeOwner)

                if ($pipeOwnerFound -and $pipeOwner -eq $processId) {
                    # Add to the results array
                    $results += [PSCustomObject]@{
                        ProcessId = $pipeOwner
                        NamedPipe = $pipe
                    }
                }

                # Close the handle to the pipe
                [Kernel32]::CloseHandle($hPipe) | Out-Null
            }
        }

        # Output the results
        $results | Format-Table -AutoSize
    } else {
        Write-Host "Process not found."
    }
}

# Example usage: Get named pipes created by msedgewebview2.exe
Get-NamedPipesByProcess -ProcessName "ms-teams"
