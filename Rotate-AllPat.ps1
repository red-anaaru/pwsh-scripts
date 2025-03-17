#!/usr/bin/env pwsh
<#
.SYNOPSIS
    This script generates a Personal Access Token (PAT) for Azure DevOps based on the specified organization.

.DESCRIPTION
    The script logs into Azure, retrieves an access token, and generates a PAT for the specified organization.
    It updates the necessary environment variables and configuration files with the new PAT.

.PARAMETER organization
    The organization for which the PAT is to be generated. Valid values are "domoreexp", "office", and "skype".

.EXAMPLE
    .\Rotate-Pat.ps1
    This example generates a PAT for the "domoreexp" organization and updates the necessary configurations.

    .\Rotate-Pat.ps1 -organization "office"
    This example generates a PAT for the "office" organization and updates the OFFICE_PAT environment variable.

.NOTES
    Author: Anand Arumugam
    Date: 10/2/2024
#>

param (
    [ValidateSet("domoreexp", "office", "skype")]
    [string]$Organization = "domoreexp",
    [Switch]$All
)

Function Get-AdoLoginToken {
    Write-Output "Logging into Azure..."
    $loginOutput = az login --tenant "microsoft.onmicrosoft.com" --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed. Please check your credentials and try again."
        exit
    }

    Write-Information "Logged into Azure successfully."
    Write-Output $loginOutput

    $token = az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to retrieve access token. Please check your Azure login status."
        exit
    }

    return $token
}

Function New-Pat {
    param (
        [string]$organization,
        $token
    )

    $headers = @{
        Authorization = "Bearer $($token.accessToken)"
        'Content-Type' = 'application/json'
    }

    switch ($organization) {
        "domoreexp" {
            $scopes = "vso.code_full vso.packaging vso.tokens vso.profile"
        }
        "office" {
            $scopes = "vso.code vso.tokens vso.profile"
        }
        "skype" {
            $scopes = "vso.packaging vso.tokens vso.profile"
        }
    }

    $patName = ("{0}VsoPat" -f $organization)

    $body = @{
        displayName = $patName
        scope = $scopes
        validTo = (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ")
        allOrgs = $false
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$organization/_apis/tokens/pats?api-version=7.1-preview.1" `
                                  -Headers $headers `
                                  -Method Post `
                                  -Body $body `
                                  -ContentType "application/json"

    if ($response -and $response.patToken) {
        Write-Output "New PAT generated!"
        return $response.patToken.token
    } else {
        Write-Error "Failed to generate PAT. Check the request body and API version."
        Exit
    }
}

Function ReplaceLine {
    [CmdletBinding()]
    param (
        [String] $LiteralPath,
        [String] $Pattern,
        [String] $Replacement,
        [Parameter(ParameterSetName = 'IfEmpty')]
        [String] $IfEmpty = '',
        [Parameter(ParameterSetName = 'IfEmptyUseReplacement')]
        [Switch] $IfEmptyUseReplacement
    )
    $Content = (Get-Content -LiteralPath $LiteralPath -ea SilentlyContinue)
    if ($Content) {
        Write-Output "Modifying existing ${LiteralPath}"
        $Content = $Content -Replace $Pattern, $Replacement
    } elseif ($IfEmpty) {
        Write-Output "${LiteralPath} does not exist, will create"
        $Content = $IfEmpty
    } elseif ($IfEmptyUseReplacement) {
        Write-Output "${LiteralPath} does not exist, will create"
        $Content = $Replacement
    } else {
        Write-Error "${LiteralPath} does not exist and I don't know how to create it"
        return
    }
    Write-Output "Writing ${LiteralPath}"
    Set-Content -LiteralPath $LiteralPath -Value $Content
}

Function Update-Npmrc {
    param (
        [string]$PAT
    )
    $Base64PAT = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($PAT))

    $npmrcContents = @"
registry=https://domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/registry
always-auth=true
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/registry/:username=npm-mirror
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/registry/:_password=${Base64PAT}
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/registry/:email=<npm requires email to be set but doesn't use the value>
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/:username=npm-mirror
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/:_password=${Base64PAT}
//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/:email=<npm requires email to be set but doesn't use the value>
"@

    ReplaceLine `
      -LiteralPath (Join-Path $HOME '.npmrc') `
      -Pattern '(//domoreexp.pkgs.visualstudio.com/_packaging/npm-mirror/npm/(registry/)?:_password=).*' `
      -Replacement "`$1${Base64PAT}" `
      -IfEmpty $npmrcContents
}

Function Update-DotEnvFile {
    param (
        [string]$PAT
    )
    ReplaceLine `
        -LiteralPath (Split-Path $PSScriptRoot -Parent | Join-Path -ChildPath .env) `
        -Pattern 'MAGLEV_DOMOREEXP_PACKAGING_TOKEN=.*' `
        -Replacement "MAGLEV_DOMOREEXP_PACKAGING_TOKEN=`"$PAT`"" `
        -IfEmptyUseReplacement
}
Function Update-DomoreexpEnvironment {
    param (
        $token
    )

    $PAT = New-Pat -organization domoreexp -token $token
    Update-Npmrc -PAT $PAT
    Update-DotEnvFile -PAT $PAT
       
    Write-Output 'Updating DOMORE_EXP_PAT environment variable'
    $Env:DOMORE_EXP_PAT = $PAT
    [System.Environment]::SetEnvironmentVariable('DOMORE_EXP_PAT', $PAT, 'User')

    If ($IsMacOS) {
        $null = nuget source remove -Name DoMoreExpNuget
        nuget source add `
            -Name DoMoreExpNuget `
            -Source https://domoreexp.pkgs.visualstudio.com/Teamspace/_packaging/teams-client-native-shell/nuget/v3/index.json `
            -Username $Env:USER `
            -Password $PAT
    }
}

Function Update-OfficeEnvironment {
    param (
        $token
    )

    $PAT = New-Pat -organization office -token $token
    Write-Output 'Updating OFFICE_PAT environment variable'
    $Env:OFFICE_PAT = $PAT
    [System.Environment]::SetEnvironmentVariable('OFFICE_PAT', $PAT, 'User')
}

Function Update-SkypeEnvironment {
    param (
        $token
    )

    $PAT = New-Pat -organization skype -token $token
    Write-Output 'Updating SKYPE_PAT environment variable'
    $Env:SKYPE_PAT = $PAT
    [System.Environment]::SetEnvironmentVariable('SKYPE_PAT', $PAT, 'User')
}

$token = Get-AdoLoginToken

if ($All) {
    Update-DomoreexpEnvironment -token $token
    Update-OfficeEnvironment -token $token
    Update-SkypeEnvironment -token $token
} elseif ($organization -eq "domoreexp") {
    Update-DomoreexpEnvironment -token $token
} elseif ($organization -eq "office") {
    Update-OfficeEnvironment -token $token
} elseif ($organization -eq "skype") {
    Update-SkypeEnvironment -token $token
} else {
    Write-Error "Invalid organization. Valid values are 'domoreexp', 'office', and 'skype'."
}
