<#
.SYNOPSIS
    This script installs the WebView2 Fixed Version Runtime.

.DESCRIPTION
    This script extracts the WebView2 Fixed Version Runtime from a CAB file and installs it to a specified path.
    It also sets a registry key to point to the installed runtime.

.PARAMETER CabFile
    The path to the CAB file containing the WebView2 Fixed Version Runtime.

.PARAMETER Version
    The version of the WebView2 Fixed Version Runtime to install.

.PARAMETER AppExeName
    The name of the application executable that will use the WebView2 Fixed Version Runtime. Defaults to "ms-teams.exe".

.PARAMETER InstallPath
    The path where the WebView2 Fixed Version Runtime will be installed. Defaults to "$env:SYSTEMDRIVE\WebView2\$Version".
.PARAMETER Undo
    Switch to undo the fixed version setup by removing installed files and deleting the registry key.

.EXAMPLE
    .\Setup-Wv2FixedRuntime.ps1 -CabFile "C:\path\to\file.cab" -Version "90.0.818.66" -InstallPath "C:\WebView2\90.0.818.66"

.EXAMPLE
    .\Setup-Wv2FixedRuntime.ps1 -AppExeName "ms-teams.exe" -Undo

.NOTES
    Author: Anand Arumugam
    Date: April 05, 2025

    Copyright (c) 2025 Microsoft Corporation. All rights reserved.
#>

param (
    [Parameter(Mandatory=$true, ParameterSetName="Install")]
    [string]$Version = "133.0.3065.92",

    [Parameter(Mandatory=$true, ParameterSetName="Install")]
    [string]$CabFile = "$env:USERPROFILE\Downloads\Microsoft.WebView2.FixedVersionRuntime.$Version.x64.cab",

    [Parameter(Mandatory=$false, ParameterSetName="Install")]
    [Parameter(Mandatory=$true, ParameterSetName="Undo")]
    [string]$AppExeName = "ms-teams.exe",

    [Parameter(Mandatory=$true, ParameterSetName="Install")]
    [string]$InstallPath = "$env:SYSTEMDRIVE\WebView2\$Version",

    [Parameter(Mandatory=$true, ParameterSetName="Undo")]
    [switch]$Undo
)

$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\WebView2\BrowserExecutableFolder"
$regValueName = $AppExeName
$BrowserExePath = Join-Path -Path $InstallPath -ChildPath "Microsoft.WebView2.FixedVersionRuntime.$Version.x64"

if ($Undo) {
    Write-Output "Undoing the fixed version setup for $AppExeName..."

    try {
        if (Test-Path -Path $regPath) {
            Remove-ItemProperty -Path $regPath -Name $regValueName -Force
            Write-Output "Removed registry key value '$regValueName' from '$regPath'."
        } else {
            Write-Output "Registry path '$regPath' does not exist."
        }
    } catch {
        Write-Error "Failed to remove registry key value: $_"
        Exit 1
    }

    try {
        if (Test-Path -Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-Output "Removed installed files from '$InstallPath'."
        } else {
            Write-Output "Install path '$InstallPath' does not exist."
        }
    } catch {
        Write-Error "Failed to remove installed files: $_"
        Exit 1
    }

    Exit 0
}

if (Test-Path -Path $InstallPath) {
    Write-Warning "The path '$InstallPath' is not empty."
    Exit 1
} else {
    New-Item -ItemType Directory -Path $InstallPath -Force
}

try {
    & expand $CabFile -F:* $InstallPath
} catch {
    Write-Error "Failed to expand the CAB file: $_"
    Exit 1
}

if (Test-Path -Path $regPath) {
    Write-Output "The registry path '$regPath' exists."
} else {
    Write-Output "Creating registry path '$regPath'"
    New-Item -Path $regPath -Force | Out-Null
}

Write-Output "Setting registry key value '$regValueName' to '$BrowserExePath'"
New-ItemProperty -Path $regPath -Name $regValueName -Value $BrowserExePath -PropertyType String -Force
if ($LASTEXITCODE -eq 0) {
    Write-Output "BrowserExecutableFolder policy for $AppExeName is set successfully."
} else {
    Write-Error "Failed to set registry key value."
    Exit 1
}
