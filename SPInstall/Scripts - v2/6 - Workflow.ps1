# Execute on DC

# Config
$DomainName = "sbp.emea.corpds.test"
$DomainNameNetBIOS = "test"
$PasswordFile = "D:\spfarm\Scripts\Shared\password.txt"
$computerNameSQL = "SQL"
$computerNameSP = "SP"
$DomainAdminAccount = "$DomainNameNetBIOS\Administrator"
$SPSetupAccount = "$DomainNameNetBIOS\sp_setup"
$SPFarmAccount = "$DomainNameNetBIOS\sp_farm"
$WSISO = ""
$SQLISO = ""
$SPISO = ""
$PrerequisitesPath = ""

# Functions
. "D:\spfarm\Scripts - v2\Shared\functions.ps1"

# Credentials for host session
$pass = Read-Password $PasswordFile -AsSecureString
$DomainCred = New-PSCredential -UserName $DomainAdminAccount -Password $pass
$SPSetupCred = New-PSCredential -UserName $SPSetupAccount -Password $pass

# Configure SQL
# !!!!!!!!!! copy files to SQL !!!!!!!!!!
$session = Connect-PSSession -ComuterName $computerNameSQL -Timeout 10 -Credential $DomainCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-file c:\sql.ps1" -Wait

    New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "SQLServer Browser service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow
}
$session | Remove-PSSession


# Add SP setup account to local Administrators group
$session = Connect-PSSession -ComuterName $computerNameSP -Timeout 10 -Credential $LocalCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
    Add-LocalGroupMember -Group "Administrators" -Member $SPSetupAccount
}
$session | Remove-PSSession

# Mount WS & SP disk images, install prerequisites (part 1), dismount disk images
$session = Connect-PSSession -ComuterName $computerNameSP -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
    $WSImage = Mount-DiskImage -ImagePath $WSISO -Access ReadOnly -StorageType ISO -PassThru
    $WSImageDriveLetter = ($WSImage | Get-Volume).DriveLetter
    $SPImage = Mount-DiskImage -ImagePath $SPISO -Access ReadOnly -StorageType ISO -PassThru
    $SPImageDriveLetter = ($SPImage | Get-Volume).DriveLetter
    Install-PreReqs1 -OfflinePath $PrerequisitesPath -WSISODriveLetter $WSImageDriveLetter -SPISODriveLetter $SPImageDriveLetter -Verbose
    $WSImage | Dismount-DiskImage
    $SPImage | Dismount-DiskImage
    Restart-Computer -Force -Confirm:$false
}
$job | Wait-Job
$session | Remove-PSSession

# Mount WS & SP disk images, install prerequisites (part 2), dismount disk images
$session = Connect-PSSession -ComuterName $computerNameSP -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
    $WSImage = Mount-DiskImage -ImagePath $WSISO -Access ReadOnly -StorageType ISO -PassThru
    $WSImageDriveLetter = ($WSImage | Get-Volume).DriveLetter
    $SPImage = Mount-DiskImage -ImagePath $SPISO -Access ReadOnly -StorageType ISO -PassThru
    $SPImageDriveLetter = ($SPImage | Get-Volume).DriveLetter
    Install-PreReqs2 -OfflinePath $PrerequisitesPath -WSISODriveLetter $WSImageDriveLetter -SPISODriveLetter $SPImageDriveLetter -Verbose
    $WSImage | Dismount-DiskImage
    $SPImage | Dismount-DiskImage
}
$job | Wait-Job
$session | Remove-PSSession

# Install SharePoint
# !!!!!!!!!! Copy xml file !!!!!!!!!!
$session = Connect-PSSession -ComuterName $computerNameSP -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
    $WSImage = Mount-DiskImage -ImagePath $WSISO -Access ReadOnly -StorageType ISO -PassThru
    $WSImageDriveLetter = ($WSImage | Get-Volume).DriveLetter
    Start-Process "$($WSImageDriveLetter):\setup.exe" `
        -ArgumentList "/config C:\sharepoint.xml" `
        -WindowStyle Hidden -Wait
    $SPImage | Dismount-DiskImage
}
$job | Wait-Job
$session | Remove-PSSession

# Add SP setup account to dbcreator, securityadmin server roles on SQL server
# !!!!!!!!!! Copy bat and sql files !!!!!!!!!!
$session = Connect-PSSession -ComuterName $computerNameSQL -Timeout 10 -Credential $DomainCred -Verbose
Invoke-Command -Session $session -ScriptBlock {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c c:\sql-config.bat" -Wait
}
$session | Remove-PSSession

# Create new SharePoint farm
# !!!!!!!!!! Copy password (?) file !!!!!!!!!!
$session = Connect-PSSession -ComuterName $computerNameSP -Timeout 10 -Credential $SPSetupCred -Verbose
$job = Invoke-Command -Session $session -AsJob -ScriptBlock {
    $passphrase = Read-Password "C:\password.txt" -AsSecureString
    $farmPassword = Read-Password "C:\password.txt" -AsSecureString
    $farmCredentials = New-PSCredential -UserName $SPFarmAccount -Password $farmPassword

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