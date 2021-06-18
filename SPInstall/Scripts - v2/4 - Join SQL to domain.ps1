# Execute on SQL

# Config
$ComputerName = "SQL"
$DomainName = "sbp.emea.corpds.test"
$DomainNameNetBIOS = "test"
$DNSIPAddress = ""
$PasswordFile = "D:\spfarm\Scripts\Shared\password.txt"

# Functions
. "D:\spfarm\Scripts\Shared\functions.ps1"

# Remoting
New-ItemProperty -Name LocalAccountTokenFilterPolicy `
  -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System `
  -PropertyType DWord -Value 1
Enable-PsRemoting -Force

# Credentials
$pass = Read-Password $PasswordFile -AsSecureString
$LocalCred = New-PSCredential -UserName "Administrator" -Password $pass
$DomainCred = New-PSCredential -UserName "$DomainNameNetBIOS\Administrator" -Password $pass

# Configure DNS
Get-NetAdapter | select -First 1 | Set-DnsClientServerAddress -ServerAddresses $DNSIPAddress
Start-Sleep -Seconds 5

# Join domain and restart
Add-Computer -NewName $ComputerName -DomainName $DomainName -LocalCredential $LocalCred -Credential $DomainCred -Force
