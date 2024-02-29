Import-Module AzureRM

$Subscription = "f9d43f74-69ff-41f4-b7bb-7fb592f2fc3a"

$VaultName = "csidne-automation-kv"

$CertName = "csidne-automation-aad-pfx"

# Comment Login after first login
# Login-AzureRmAccount -EnvironmentName (Get-AzureRmEnvironment -Name AzureCloud) -SubscriptionName $Subscription

Get-AzureRMKeyVault -VaultName $VaultName

$Secret = Get-AzureKeyVaultSecret -VaultName $VaultName -Name $CertName
$cert = Get-AzureKeyVaultCertificate -VaultName $VaultName -Name $CertName

Write-Host Secret: $Secret.SecretValueText
Write-Host Cert: $cert.Certificate
# Write-Host CertPubKey: $cert.Certificate.PublicKey.EncodedKeyValue.RawData.ToString()

$Bytes = [Convert]::FromBase64String($Secret.SecretValueText)
$CertBytes = [Convert]::FromBase64String($cert.Certificate.PublicKey.EncodedKeyValue.RawData)

[IO.File]::WriteAllBytes('d:\Temp\TestCert.pfx', $Bytes)
[IO.File]::WriteAllBytes('d:\Temp\TestCert.cer', $CertBytes)