param(
    [string]$ProcessName = "ms-teams",
    [string]$OutputPath = "$env:USERPROFILE\Downloads"
)

Get-Process $ProcessName | ForEach-Object {
    $process = $_
    $process.Modules | ForEach-Object {
        [PSCustomObject]@{
            ModuleName = $_.ModuleName
            ModuleSize = $_.ModuleMemorySize
            FullPath = $_.FileName
            CompanyName = $_.FileVersionInfo.CompanyName
            Description = $_.FileVersionInfo.FileDescription
        }
    }
} | Export-Csv -Path "$OutputPath\$ProcessName_modules_info.csv" -NoTypeInformation