Param(
  [Parameter()]
  [ValidateSet("x64","arm64","x86")]
  [string] $arch = "x64",
  [Parameter()]
  [ValidateSet("release","debug")]
  [string] $config = "debug",
  [Switch] $dryRun = $false
)

if ($PSVersionTable.Platform -eq "Win32NT") {
  $plat = "windows"
} else {
  $plat = "mac"
}

if ($config -eq "release") {
  $config = "RelWithDebInfo"
} else {
  $config = "Debug"
}

if ($dryRun) {
  Write-Host "ctest --preset $arch-$plat --build-config $config --verbose"
  Exit
} else {
  ctest --preset $arch-$plat --build-config $config --verbose
  Exit
}
