param(
    [string]$ProcessName = "ms-teams",
    [string]$OutputPath = "$env:USERPROFILE\Downloads"
)

$CsvFilePath = Join-Path -Path $OutputPath -ChildPath ("{0}_modules_info.csv" -f $ProcessName)
Write-Debug "CsvFilePath: $CsvFilePath"

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
} | Export-Csv -Path $CsvFilePath -NoTypeInformation

Write-Host "Modules information exported to $CsvFilePath"