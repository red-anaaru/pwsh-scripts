param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PkgPath=$(throw "-PkgPath is required.")
)
dism /online /norestart /add-package /packagepath:$PkgPath
Set-Service sshd -StartupType Automatic
Set-Service ssh-agent -StartupType Automatic
Start-Service sshd
Start-Service ssh-agent
