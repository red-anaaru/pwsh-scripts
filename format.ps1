#!/usr/bin/env pwsh

[CmdletBinding(DefaultParameterSetName = 'Root')]
Param (
    [Parameter(ParameterSetName = 'Root')]
    [String] $Root = "$(Split-Path -Parent $PSScriptRoot)\src",

    [String] $ClangFormat = "",

    [Parameter(ParameterSetName = 'LiteralPath')]
    [String[]] $LiteralPath,

    [String[]] $Exclude = @('_build', '_projects', 'external', 'generated', 'resources', 'web'),
    [String[]] $IncludeExtension = @('*.cc', '*.cpp', '*.h', '*.hpp', '*.m', '*.mm'),
    [String[]] $ExcludeExtension = @('*.g.h', '*.g.cpp'),

    [Switch] $Fix = $False
)

Begin {
    $Script:ErrorsFound = 0

    $ExpectedVersion = 18
    If ($IsMacOS) {
        $llvm_install_cmd = 'brew install llvm@18 --quiet'
        $llvm_uninstall_cmd = 'brew uninstall --force llvm'
    } Else {
        $llvm_install_cmd = 'winget install --id=LLVM.LLVM -v "18.1.8" --silent'
        $llvm_uninstall_cmd = 'winget uninstall --id LLVM.LLVM --silent'
    }

    If (-Not $ClangFormat) {
       $ClangFormat = @(Get-Command `
            -Name @(
                "/usr/local/opt/llvm@${ExpectedVersion}/bin/clang-format", 
                "${Env:ProgramFiles}\LLVM\bin\clang-format.exe",
                "clang-format") `
            -ErrorAction SilentlyContinue)[0].Source
    }

    $ClangInstallInstructions = "Please install LLVM ${ExpectedVersion} from https://github.com/llvm/llvm-project/releases"

    If (-Not $ClangFormat) {
        Throw "clang-format not found. Please make sure it's on the PATH or installed in the default location. ${ClangInstallInstructions}"
    }

    $ClangFormatVersion = & $ClangFormat --version
    If ($ClangFormatVersion -NotMatch "clang-format version ${ExpectedVersion}\.") {
        Write-Error "Expected ${ExpectedVersion}, actual: ${ClangFormatVersion}"
        Write-Host "Running: $llvm_uninstall_cmd"
        Invoke-Expression $llvm_uninstall_cmd
        Write-Host "Running: $llvm_install_cmd"
        Invoke-Expression $llvm_install_cmd
        Write-Host "Please restart the terminal and run 'scripts/format.ps1 -fix'"
        Exit 1
    }
    Write-Verbose $ClangFormatVersion

    $ClangArgs = @('--Werror')
    If ($VerbosePreference -Eq 'Continue') {
        $ClangArgs += '--verbose'
    }

    Function Format-CppFile {
        [CmdletBinding()]
        Param (
            [Parameter(Position = 0, ValueFromPipeline)]
            [IO.FileInfo] $File
        )
        Process {
            If ($Fix) {
                & $ClangFormat @ClangArgs -i $File.FullName
            }
            Else {
                & $ClangFormat @ClangArgs --dry-run $File.FullName
                $Script:ErrorsFound += $LASTEXITCODE
            }
        }
    }

    Function IsExtensionExcluded([String]$Name) {
        If ($Name -NotLike '*.*') {
            Return $False
        }
        ForEach ($Ext In $ExcludeExtension) {
            If ($Name -Like $Ext) { Return $True }
        }
        ForEach ($Ext In $IncludeExtension) {
            If ($Name -Like $Ext) { Return $False }
        }
        Return $True
    }

    Function IsExcluded([String]$Name) {
        If (IsExtensionExcluded $Name) {
            Return $True
        }
        ForEach ($E In $Exclude) {
            $EPath = (Join-Path $Root $E) 
            If ($Name -Eq $EPath) {
                Return $True
            }
            If (-Not $EPath.EndsWith([IO.Path]::DirectorySeparatorChar)) {
                $EPath += [IO.Path]::DirectorySeparatorChar
            }
            If ($Name.StartsWith($EPath)) {
                Return $True
            }
        }
        Return $False
    }
}

Process {
    If ($PSCmdlet.ParameterSetName -eq 'Root') {
        $Items = Get-ChildItem -LiteralPath $Root -Directory -Recurse `
        | Where-Object { -Not (IsExcluded $_.FullName) } `
        | ForEach-Object { 
            Get-ChildItem `
                -Path "$($_.FullName)\*" `
                -Include $IncludeExtension
        } `
        | Where-Object { -Not (IsExcluded $_.FullName) } `
    }
    Else {
        $Items = Get-Item -LiteralPath $LiteralPath `
        | Where-Object { -Not (IsExcluded $_.FullName) } 
    }

    $Items | Format-CppFile 
} 

End {
    Exit $Script:ErrorsFound
}