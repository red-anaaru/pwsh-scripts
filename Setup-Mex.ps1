param (
   [string]$OutDir = "$env:LOCALAPPDATA\Temp"
)

$ErrorActionPreference = "Stop"

# Define the NuGet source URL as a constant
$nugetSourceUrl = "https://mexext.pkgs.visualstudio.com/Mex/_packaging/Mex_PublicPackages@Release/nuget/v3/index.json"

# Check if nuget is available
if (-not (Get-Command nuget -ErrorAction SilentlyContinue)) {
   # Install nuget using winget if not available
   Start-Process -FilePath "winget" -ArgumentList "install -e --id NuGet.NuGet" -NoNewWindow -Wait
}

# Step 1: Install the NuGet package 'MexOfficialX64' without versioning and output it to the local temp directory
Start-Process -FilePath "nuget" -ArgumentList "install MexOfficialX64 -ExcludeVersion -OutputDirectory $OutDir\Mex64 -source $nugetSourceUrl" -NoNewWindow -Wait -PassThru | Write-Output

# Step 2: Copy the mex.dll file from the installed package to %localappdata%\dbg\EngineExtensions and C:\Debuggers\winext
Copy-Item -Path "$OutDir\Mex64\MexOfficialX64\lib\mex.dll" -Destination "$env:LOCALAPPDATA\dbg\EngineExtensions" -Force
$debuggersExists = Test-Path "C:\Debuggers"
if ($debuggersExists) {
   Copy-Item -Path "$OutDir\Mex64\MexOfficialX64\lib\mex.dll" -Destination "C:\Debuggers\winext" -Force
}

# Step 3: Install the NuGet package 'MexOfficialX86' without versioning and output it to the local temp directory
Start-Process -FilePath "nuget" -ArgumentList "install MexOfficialX86 -ExcludeVersion -OutputDirectory $OutDir\Mex32 -source $nugetSourceUrl" -NoNewWindow -Wait -PassThru | Write-Output

# Step 4: Copy the mex.dll file from the installed package to %localappdata%\dbg\EngineExtensions32 and C:\Debuggers\wow64\winext
Copy-Item -Path "$OutDir\Mex32\MexOfficialX86\lib\mex.dll" -Destination "$env:LOCALAPPDATA\dbg\EngineExtensions32" -Force
if ($debuggersExists) {
   Copy-Item -Path "$OutDir\Mex32\MexOfficialX86\lib\mex.dll" -Destination "C:\Debuggers\wow64\winext" -Force
}

# Step 5: Cleanup - Delete the files downloaded using nuget to $OutDir\Mex64 and $OutDir\Mex32
Remove-Item -Path "$OutDir\Mex64" -Recurse -Force
Remove-Item -Path "$OutDir\Mex32" -Recurse -Force

Write-Host "All steps completed successfully."
