$organization = 'domoreexp'

# $headers = @{
#     Authorization = "Bearer " + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($pat)"))
# }

# $response = Invoke-RestMethod -Uri "https://dev.azure.com/$organization/_apis/projects?api-version=6.0" -Headers $headers
    
# $prettyJson = $response | ConvertTo-Json -Depth 2
# Write-Output $prettyJson

$env:DOMORE_EXP_PAT | az devops login --organization "https://dev.azure.com/$organization"

# if ($response -ne $null) {
    # Write-Output "PAT is valid."
# } else {
#    Write-Output "PAT is invalid."
    $body = @{
        displayName = $organization
        scope = "vso.build vso.code_full vso.tokens vso.profile"
        validTo = (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ")
        allOrgs = $false
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "https://vssps.dev.azure.com/$organization/_apis/tokens/pats?api-version=7.1-preview.1" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    
    # $prettyJson = $response | ConvertTo-Json -Depth 2
    $response | Out-file $env:TEMP\response.html -Encoding UTF8
    if ($response) {
        Start-Process $env:TEMP\response.html
        # $newPat = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($response.patToken.token)"))
        # Write-Output "New PAT: $newPat"
    }
