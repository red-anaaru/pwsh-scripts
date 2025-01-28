<#
.SYNOPSIS
    Installs the signer certificate from an MSIX package to a specified certificate store.

.DESCRIPTION
    This script retrieves the Authenticode signature from a specified MSIX package and installs the signer certificate to a specified certificate store.

.PARAMETER msixPath
    The path to the MSIX package file.

.PARAMETER certStore
    The certificate store where the signer certificate will be installed. Default is "Cert:\LocalMachine\Root".

.EXAMPLE
    .\Install-MsixCert.ps1 -msixPath "C:\path\to\your\app.msix"
    This example installs the signer certificate from the specified MSIX package to the default certificate store.

.EXAMPLE
    .\Install-MsixCert.ps1 -msixPath "C:\path\to\your\app.msix"
    This example installs the signer certificate from the specified MSIX package to the specified certificate store.

#>

param (
    [string]$msixPath,
    [string]$certStore = "Cert:\LocalMachine\Root"
)

# Get the Authenticode signature of the specified msix file
$sig = Get-AuthenticodeSignature -FilePath $msixPath

# Open the specified certificate store
$store = Get-Item $certStore
$store.Open('ReadWrite')

# Add the SignerCertificate to the certificate store
$store.Add($sig.SignerCertificate)

# Close the certificate store
$store.Close()
