<#
.SYNOPSIS
Executes a command safely with error handling, with optional token authentication for ADO or ECS.

.DESCRIPTION
The script executes a provided command with arguments, with the option to use token authentication.
It includes error handling and parameter validation.

.PARAMETER resourceId
The ID of the resource. Supported values are "ado", "azure-exp", "azure-kv", "azure-storage", "ecs", "ecs-int", "kusto-aria", "skynet". Mandatory.

.PARAMETER scope
The scope for the resource

.PARAMETER organization
The organization to which the resource belongs to. Defaults to $env:SYSTEM_COLLECTIONURI

.PARAMETER projectName
The project in which the resource is used. Defaults to $env:SYSTEM_TEAMPROJECT

.PARAMETER useTokenAuth
Indicates whether to use token authentication. If true, the script retrieves an access token. Mandatory.

.PARAMETER isStandaloneToken
Specifies whether a standalone token should be obtained.
This token can be utilized in subsequent Azure DevOps tasks.
If true, the script sets the token as an ADO secret variable. Optional.

.PARAMETER standaloneTokenName
The name of the standalone token ADO variable. Optional.

.PARAMETER command
The command to be executed. Optional.

.PARAMETER arguments
The arguments for the command. Optional.

.EXAMPLE
PS> .\wif-sc-auth.ps1 -resourceId "ecs"
                      -useTokenAuth $true
                      -command "node tools/build/cli/ship-scorecard-ci.js"
                      -arguments "--env=dev --cloud=t1legacy --accessToken"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $resourceId,

    [Parameter(Mandatory = $false)]
    [string] $scope,

    [Parameter(Mandatory = $false)]
    [string] $organization,

    [Parameter(Mandatory = $false)]
    [string] $projectName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $useTokenAuth,

    [Parameter(Mandatory = $false)]
    [string] $isStandaloneToken,

    [Parameter(Mandatory = $false)]
    [string] $standaloneTokenName,

    [Parameter(Mandatory = $false)]
    [string] $command,

    [Parameter(Mandatory = $false)]
    [string] $arguments
)

<# Function to check if an input parameter is valid #>
function Test-Parameters([string]$parameter, [string]$value, [array]$array) {
    $value = $value.ToLower()
    Write-Host "$parameter : $value"
    if ($value -NotIn $array) {
        Write-Host "Invalid $parameter : $value"
        Write-Host "Supported $parameter : $array"
        throw "InvalidParameter"
    }
}

<# Function to invoke a script block with retry logic #>
function Invoke-RetryCommand {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock] $ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int] $MaxRetryCount = 3,

        [Parameter(Mandatory = $false)]
        [int] $RetryIntervalInSeconds = 5
    )

    $retryCount = 0
    while ($retryCount -lt $MaxRetryCount) {
        try {
            Write-Verbose "Executing script block..."
            & $ScriptBlock
            break
        }
        catch {
            Write-Error "An error occurred while executing the script block: $_"
            $retryCount++
            if ($retryCount -eq $MaxRetryCount) {
                Write-Error "Script block failed after $MaxRetryCount attempts."
                throw
            }
            Write-Host "Retrying in $RetryIntervalInSeconds seconds..."
            Start-Sleep -Seconds $RetryIntervalInSeconds
        }
    }
}

<# Function to safely execute a command #>
function Invoke-SafeCommand {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Command,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Arguments,

        [Parameter()]
        [string] $AccessToken,

        [Parameter()]
        [string] $ErrorMessage = "An error occurred while executing the command."
    )

    try {
        if (![String]::IsNullOrEmpty($AccessToken)) {
            Write-Host "Executing command: $Command $Arguments TOKEN"
            $result = Invoke-Expression -Command "$Command $Arguments $AccessToken"
            Write-Output $result
        }
        else {
            Write-Host "Executing command: $Command $Arguments"
            $result = Invoke-Expression -Command "$Command $Arguments"
            Write-Output $result
        }
    }
    catch {
        Write-Error "$ErrorMessage `n$($_.Exception.Message)"
        throw
    }
}

<# Function to retrieve an access token #>
function Get-AccessToken {
    $getAccessToken = {
        <# Set Resource ID based on the $resourceId name #>
        $resourceId = $resourceIdTable[$resourceId]

        # Retrieve the access token
        Write-Host "Retrieving Access Token for Resource ID: $resourceId"
        if (-not [String]::IsNullOrEmpty($scope)) {
            $token = az account get-access-token --resource "$resourceId" --scope "$scope" --query "accessToken" --output tsv
        }
        else {
            $token = az account get-access-token --resource "$resourceId" --query "accessToken" --output tsv
        }
        if (-not $token) {
            throw "Failed to get Access Token!"
        }
        Write-Host "Access Token retrieved successfully."
        return $token
    }
    Invoke-RetryCommand -ScriptBlock $getAccessToken
}

<# Supported Resource IDs. Keep in alphabetical order. #>
$resourceIdList = @( "ado", "azure-exp", "azure-kv", "azure-storage", "ecs", "ecs-int", "kusto-aria", "skynet" )
[hashtable] $resourceIdTable = @{
    "ado"           = "499b84ac-1321-427f-aa17-267ca6975798"
    "azure-exp"     = "https://exp.azure.net"
    "azure-kv"      = "https://vault.azure.net"
    "azure-storage" = "https://storage.azure.com"
    "ecs"           = "https://ecs.skype.ame.gbl"
    "ecs-int"       = "https://ecs.skype.test.ame.gbl"
    "kusto-aria"    = "https://kusto.aria.microsoft.com"
    "skynet"        = "72f42fd8-61b1-4769-84ea-1942d78a61a5"
}

<# Check if all input parameters are valid #>
Test-Parameters -parameter ResourceId -value $resourceId -array $resourceIdList

<# Configure Azure DevOps defaults #>
if ([String]::IsNullOrEmpty($organization)) {
    $org = $env:SYSTEM_COLLECTIONURI
} else {
    $org = $organization
}
if ([String]::IsNullOrEmpty($projectName)) {
    $project = $env:SYSTEM_TEAMPROJECT
} else {
    $project = $projectName
}

$configureAzDevOps = {
    az devops configure --defaults organization="$org" project="$project"
    az devops configure --list
}
Invoke-RetryCommand -ScriptBlock $configureAzDevOps

<# Execute the main command #>
if ($useTokenAuth -eq "true") {
    $accessToken = Get-AccessToken
    if ($isStandaloneToken -eq "true") {
        Write-Host "isStandaloneToken: $isStandaloneToken"
        if ([String]::IsNullOrEmpty($standaloneTokenName)) {
            Write-Host "Standalone Token ADO Variable Name: standaloneToken"
            Write-Host "accessToken from Office: $accessToken"
            Write-Host "##vso[task.setvariable variable=standaloneToken;issecret=true]$accessToken"
        }
        else {
            Write-Host "Standalone Token ADO Variable Name: $standaloneTokenName"
            Write-Host "##vso[task.setvariable variable=$standaloneTokenName;issecret=true]$accessToken"
        }
    }
    else {
        Invoke-SafeCommand -Command $command -Arguments $arguments -AccessToken $accessToken -ErrorMessage "Command failed: $command $arguments TOKEN"
    }
}
else {
    Write-Host "Using logged-in Azure CLI session..."
    Invoke-SafeCommand -Command $command -Arguments $arguments -ErrorMessage "Command failed: $command $arguments"
}
