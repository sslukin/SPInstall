# Execute on DC

# Config
$DomainName = "sbp.emea.corpds.test"
$DomainNameNetBIOS = "test"
$PasswordFile = "D:\spfarm\Scripts\Shared\password.txt"

# Functions
. "D:\spfarm\Scripts\Shared\functions.ps1"

# Remoting
New-ItemProperty -Name LocalAccountTokenFilterPolicy `
  -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
  -PropertyType DWord -Value 1
Enable-PsRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Credentials
$pass = Read-Password $PasswordFile -AsSecureString

# Install AD and restart
Install-Forest -FQDN $DomainName -SLD $DomainNameNetBIOS -password $pass -Verbose
Restart-Computer -Force -Confirm:$false 
