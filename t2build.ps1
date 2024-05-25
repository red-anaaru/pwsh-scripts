Param(
  [Parameter()]
  [ValidateSet("x64","arm64","x86")]
  [string] $arch = "x64",
  [Parameter()]
  [ValidateSet("release","debug")]
  [string] $config = "debug",
  [Parameter()]
  [ValidateSet("release","debug")]
  [string] $target = "ALL_BUILD",
  [Switch] $preset = $false,
  [Switch] $clean = $false,
  [Switch] $dryRun = $false
)

if ($PSVersionTable.Platform -eq "Win32NT") {
  $plat = "windows"
} else {
  $plat = "mac"
}

if ($preset) {
  cmake --preset=$arch-$plat
  Exit
}

if ($config -eq "release") {
  $config = "RelWithDebInfo"
} else {
  $config = "Debug"
}

if ($clean) {
  Write-Host "cmake --build . --config $config --target clean"
  cmake --build . --config $config --target clean
}

if ($dryRun) {
  Write-Host "cmake --preset $arch-$plat"
  Write-Host "cmake --build --preset $arch-$plat --config $config --target ALL_BUILD"
  Exit
} else {
  cmake --preset $arch-$plat
  cmake --build --preset $arch-$plat --config $config --target ALL_BUILD
  Exit
}
