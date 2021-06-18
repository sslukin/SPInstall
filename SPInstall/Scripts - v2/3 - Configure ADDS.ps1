# --- Functions ---
. "D:\spfarm\Scripts\Shared\functions.ps1"

# Credentials for host session
$pass = Read-Password "D:\spfarm\Scripts\Shared\password.txt" -AsSecureString
$LocalCred = New-PSCredential -UserName "Administrator" -Password $pass
$DomainCred = New-PSCredential -UserName "test\Administrator" -Password $pass
$SPSetupCred = New-PSCredential -UserName "test\sp_setup" -Password $pass


# initial start of all VMs
"DC", "SQL", "SP" | % { Start-VM -Name "SPFarm-$_" }

# --- 1: Configure DC ---
$session = Connect-PSSession -VMName "SPFarm-DC" -Timeout 10 -Credential $LocalCred -Verbose

Invoke-Command -Session $session -ScriptBlock {
. "C:\functions.ps1"

Configure-NetworkAdapter -Adapter "Ethernet" -IPAddress 10.0.0.1 -ServerAddresses 10.0.0.1 -PrefixLength 8

$pass = Read-Password "c:\password.txt" -AsSecureString
Install-Forest -FQDN "sbp.emea.corpds.test" -SLD "test" -password $pass -Verbose
Restart-Computer -Force -Confirm:$false 
}
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-DC" -Timeout 5 -Credential $DomainCred -Verbose

Invoke-Command -Session $session -ScriptBlock {
. "C:\functions.ps1"

Wait-ADInit -Timeout 5 -Verbose$pass = Read-Password "c:\password.txt" -AsSecureStringCreate-Accounts -OU "SharePoint Accounts" -OUPath "DC=sbp,DC=emea,DC=corpds,DC=test" `-password $pass -FQDN "sbp.emea.corpds.test" -CSVPath "c:\accounts.txt" -Verbose}$session | Remove-PSSession


# --- 2: Configure SQL ---

$session = Connect-PSSession -VMName "SPFarm-SQL" -Timeout 10 -Credential $LocalCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
. "C:\functions.ps1"

Configure-NetworkAdapter -Adapter "Ethernet" -IPAddress 10.0.0.2 -ServerAddresses 10.0.0.1 -PrefixLength 8
Start-Sleep -Seconds 5

$pass = Read-Password "C:\password.txt" -AsSecureString
$LocalCred = New-PSCredential -UserName "Administrator" -Password $pass
$DomainCred = New-PSCredential -UserName "test\Administrator" -Password $pass
Add-Computer -ComputerName "SQL" -DomainName "sbp.emea.corpds.test" -LocalCredential $LocalCred -Credential $DomainCred -Force
Restart-Computer -Force -Confirm:$false
}
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SQL" -Timeout 10 -Credential $DomainCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
Start-Process -FilePath "powershell.exe" -ArgumentList "-file c:\sql.ps1" -Wait

New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "SQLServer Browser service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow
}
$session | Remove-PSSession

# --- 3: Configure SP ---

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $LocalCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
. "C:\functions.ps1"

Configure-NetworkAdapter -Adapter "Ethernet" -IPAddress 10.0.0.3 -ServerAddresses 10.0.0.1 -PrefixLength 8
Start-Sleep -Seconds 5

$pass = Read-Password "C:\password.txt" -AsSecureString
$LocalCred = New-PSCredential -UserName "Administrator" -Password $pass
$DomainCred = New-PSCredential -UserName "test\Administrator" -Password $pass
Add-Computer -ComputerName "SP" -DomainName "sbp.emea.corpds.test" -LocalCredential $LocalCred -Credential $DomainCred -Force
Restart-Computer -Force -Confirm:$false
}
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $DomainCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
Add-LocalGroupMember -Group "Administrators" -Member "test\sp_setup"
}
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
. "C:\functions.ps1"

$path = "C:\files\Prerequisites"

Install-PreReqs1 -OfflinePath $path -WSISODriveLetter "d" -SPISODriveLetter "e" -Verbose
Restart-Computer -Force -Confirm:$false
}
$job | Wait-Job
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
. "C:\functions.ps1"

$path = "C:\files\Prerequisites"
Install-PreReqs2 -OfflinePath $path -WSISODriveLetter "d" -SPISODriveLetter "e" -Verbose
}
$job | Wait-Job
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
. "C:\functions.ps1"
Start-Process "e:\setup.exe" `
-ArgumentList "/config C:\sharepoint.xml" `
-WindowStyle Hidden -Wait
}
$job | Wait-Job
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SQL" -Timeout 10 -Credential $DomainCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
Start-Process -FilePath "cmd.exe" -ArgumentList "/c c:\sql-config.bat" -Wait
}
$session | Remove-PSSession

$session = Connect-PSSession -VMName "SPFarm-SP" -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
. "C:\functions.ps1"
$passphrase = Read-Password "C:\password.txt" -AsSecureString
$farmPassword = Read-Password "C:\password.txt" -AsSecureString
$farmCredentials = New-PSCredential -UserName "test\sp_farm" -Password $farmPassword

Configure-SharePointFarm `
-DBServer "sql" -DBConfigName "SharePoint_Config" `
-DBAdminContentName "SharePoint_AdminContent" `
-passphrase $passphrase -Port 8000 -AuthProvider "NTLM" `
-FarmCredentials $farmCredentials -Verbose

}
$job | Wait-Job
Write-Host "The end"

$session | Remove-PSSession

# end of script