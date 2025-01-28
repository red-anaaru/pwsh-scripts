# Define variables
$organization = "office"
$patName = "OfficeVsoPAT"
$expirationDate = (Get-Date).AddDays(30).ToString("yyyy-MM-ddTHH:mm:ssZ")
$scope = "vso.code_full"
$token = $env:OFFICE_PAT  # Use an existing PAT with sufficient permissions to create a new PAT

# Create the PAT
$body = @{
    "displayName" = $patName
    "scope" = $scope
    "validTo" = $expirationDate
    "allOrgs" = $false
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Basic " + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$token"))
}

$response = Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$organization/_apis/tokens/pats?api-version=7.1-preview.1" -Method Post -Headers $headers -Body $body

# Output the PAT
$response.patToken.token
