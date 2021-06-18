function Connect-PSSession {
    param (
        [Parameter(Mandatory)]
        [string]$ComuterName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory)]
        [System.UInt16]$Timeout
    )

    $session = $null
    $running = $false

    do
    {
        $session = New-PSSession -ComputerName $ComuterName -Credential $Credential -ErrorAction SilentlyContinue -ErrorVariable err
        if ($err)
        {
            Write-Verbose $err[0]
            Write-Verbose "Error connecting to $ComuterName"
            Write-Verbose "Another attempt in $Timeout seconds"
            Start-Sleep -Seconds $Timeout

        }
        else
        {
            $running = $true
        }

    } while (!$running)

    return $session
}

function Wait-ADInit {
    param (
        [Parameter(Mandatory)]
        [System.UInt16]$Timeout
    )
    $ready = $false

    Write-Verbose "Wait for AD module"
    do
    {
        Import-Module activedirectory -ErrorAction SilentlyContinue -ErrorVariable err
        if ($err)
        {
            Write-Verbose $err[0]
            Write-Verbose "Error loading AD module"
            Write-Verbose "Another attempt in $Timeout seconds"
            Start-Sleep -Seconds $Timeout
        }
        else
        {
            $ready = $true
        }

    } while (!$ready)

    $ready = $false
    Write-Verbose "Wait for Domain controller"
    do
    {
        Get-ADDomainController -ErrorAction SilentlyContinue -ErrorVariable err | Out-Null
        if ($err)
        {
            Write-Verbose $err[0]
            Write-Verbose "Error contacting DC"
            Write-Verbose "Another attempt in $Timeout seconds"
            Start-Sleep -Seconds $Timeout
        }
        else
        {
            $ready = $true
        }

    } while (!$ready)
}

function Configure-NetworkAdapter {
    param (
        [Parameter(Mandatory)]
        [string]$Adapter,

        [Parameter(Mandatory)]
        [string]$IPAddress,

        [Parameter(Mandatory)]
        [string]$ServerAddresses,

        [Parameter(Mandatory)]
        [byte]$PrefixLength
    )

    $net = Get-NetAdapter $Adapter
    $net | new-NetIPAddress -IPAddress $IPAddress -PrefixLength $PrefixLength -AddressFamily IPv4
    $net | Set-DnsClientServerAddress -ServerAddresses $ServerAddresses
}

function Install-Forest {
    param (
        [Parameter(Mandatory)]
        [string]$FQDN,

        [Parameter(Mandatory)]
        [string]$SLD,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$password
        )

# ADDS role setup
Write-Verbose "Installing ADDS"
Install-WindowsFeature DNS,AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
Write-Verbose "Installing ADDS done"

# Domain setup
Import-Module ADDSDeployment

Write-Verbose "Installing ADDS forest - $FQDN"
#properties of the domain
Install-ADDSForest `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "Win2012" `
-DomainName $FQDN `
-DomainNetbiosName $SLD `
-ForestMode "Win2012" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$true `
-SysvolPath "C:\Windows\SYSVOL" `
-SafeModeAdministratorPassword $password `
-Force:$true

Write-Verbose "Installing ADDS forest done"
}

function Create-Accounts {
    param (
        [Parameter(Mandatory)]
        [string]$OU,

        [Parameter(Mandatory)]
        [string]$OUPath,

        [Parameter(Mandatory)]
        [string]$CSVPath,
        
        [Parameter(Mandatory)]
        [string]$FQDN,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$password
        )

Write-Verbose "New OU"
New-ADOrganizationalUnit -Name $OU -Path $OUPath Write-Verbose "Create AD accounts"Import-Csv -Path $CSVPath | % `{    $acc = $_.Name    New-ADUser -Name $acc `    -CannotChangePassword:$true `    -ChangePasswordAtLogon:$false `    -DisplayName $acc `    -PasswordNeverExpires:$true `    -Path "OU=$OU,$OUPath" `    -SamAccountName $acc `    -UserPrincipalName "$acc@$FQDN" `    -PassThru | `    Set-ADAccountPassword -NewPassword $password -Confirm:$false -PassThru | `    Enable-ADAccount}

}

function Install-PreReqs1 {
    param (
        [Parameter(Mandatory)]
        [string]$OfflinePath,

        [Parameter(Mandatory)]
        [string]$WSISODriveLetter,

        [Parameter(Mandatory)]
        [string]$SPISODriveLetter
        )

    Write-Verbose "Installing Windows features"
    Install-WindowsFeature NET-HTTP-Activation,NET-Non-HTTP-Activ,NET-WCF-Pipe-Activation45,NET-WCF-HTTP-Activation45,Web-Server,Web-WebServer,Web-Common-Http,Web-Static-Content,Web-Default-Doc,Web-Dir-Browsing,Web-Http-Errors,Web-App-Dev,Web-Asp-Net,Web-Asp-Net45,Web-Net-Ext,Web-Net-Ext45,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Health,Web-Http-Logging,Web-Log-Libraries,Web-Request-Monitor,Web-Http-Tracing,Web-Security,Web-Basic-Auth,Web-Windows-Auth,Web-Filtering,Web-Performance,Web-Stat-Compression,Web-Dyn-Compression,Web-Mgmt-Tools,Web-Mgmt-Console,WAS,WAS-Process-Model,WAS-NET-Environment,WAS-Config-APIs,Windows-Identity-Foundation,Xps-Viewer `
    -IncludeManagementTools -verbose -Source "$($WSISODriveLetter):\sources\sxs"
    Write-Verbose "Installing Windows features done"

    $path = $OfflinePath

    Write-Verbose "Installing SharePoint prerequisites part 1"
    Start-Process "$($SPISODriveLetter):\PrerequisiteInstaller.exe" -Wait `
    -ArgumentList "/unattended `
    /SQLNCli:$path\SQLNCli\sqlncli.msi `
    /Sync:$path\Sync\Synchronization.msi `
    /AppFabric:$path\AppFabric\WindowsServerAppFabricSetup_x64.exe `
    /IDFX11:$path\IDFX11\MicrosoftIdentityExtensions-64.msi `
    /MSIPCClient:$path\MSIPCClient\setup_msipc_x64.exe `
    /WCFDataServices56:$path\WCFDataServices56\WcfDataServices.exe `
    /MSVCRT11:$path\MSVCRT11\vcredist_x64.exe `
    /MSVCRT141:$path\MSVCRT141\vc_redist.x64.exe `
    /KB3092423:$path\KB3092423\AppFabric-KB3092423-x64-ENU.exe `
    /DotNet472:$path\DotNet472\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" 
    Write-Verbose "Installing SharePoint prerequisites part 1 done"
}

function Install-PreReqs2 {
    param (
        [Parameter(Mandatory)]
        [string]$OfflinePath,

        [Parameter(Mandatory)]
        [string]$WSISODriveLetter,

        [Parameter(Mandatory)]
        [string]$SPISODriveLetter
        )

    $path = $OfflinePath

    Write-Verbose "Installing SharePoint prerequisites part 2"
    Start-Process "$($SPISODriveLetter):\PrerequisiteInstaller.exe" -Wait `
    -ArgumentList "/unattended /continue`
    /SQLNCli:$path\SQLNCli\sqlncli.msi `
    /Sync:$path\Sync\Synchronization.msi `
    /AppFabric:$path\AppFabric\WindowsServerAppFabricSetup_x64.exe `
    /IDFX11:$path\IDFX11\MicrosoftIdentityExtensions-64.msi `
    /MSIPCClient:$path\MSIPCClient\setup_msipc_x64.exe `
    /WCFDataServices56:$path\WCFDataServices56\WcfDataServices.exe `
    /MSVCRT11:$path\MSVCRT11\vcredist_x64.exe `
    /MSVCRT141:$path\MSVCRT141\vc_redist.x64.exe `
    /KB3092423:$path\KB3092423\AppFabric-KB3092423-x64-ENU.exe `
    /DotNet472:$path\DotNet472\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" 
    Write-Verbose "Installing SharePoint prerequisites part 2 done"
}

function Configure-SharePointFarm {
    param (
        [Parameter(Mandatory)]
        [string]$DBServer,

        [Parameter(Mandatory)]
        [string]$DBConfigName,

        [Parameter(Mandatory)]
        [string]$DBAdminContentName,

        [Parameter(Mandatory)]
        [string]$Port,

        [Parameter(Mandatory)]
        [string]$AuthProvider,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$passphrase,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$FarmCredentials
        )

Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

Write-Verbose "Configuring SharePoint farm"
New-SPConfigurationDatabase `
–DatabaseName $DBConfigName `
–DatabaseServer $DBServer `
-AdministrationContentDatabaseName $DBAdminContentName `
–Passphrase $passphrase `
–FarmCredentials $FarmCredentials -LocalServerRole Custom

Install-SPHelpCollection -All

Initialize-SPResourceSecurity

Install-SPService

Install-SPFeature –AllExistingFeatures

New-SPCentralAdministration -Port $Port -WindowsAuthProvider $AuthProvider

Install-SPApplicationContent

Start-Service SPTimerV4

Write-Verbose "Configuring SharePoint farm done"

}

function New-PSCredential {
    param (
        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter(Mandatory)]
        [System.Security.SecureString]$Password
        )

$cred = New-Object System.Management.Automation.PSCredential ($UserName, $Password)
return $cred
}

function Read-Password {
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,
        [switch]$AsSecureString
        )
    $pass = Get-Content -Path $FilePath
    if ($AsSecureString.IsPresent) { return ConvertTo-SecureString $pass -AsPlainText -Force }
    else { return $pass }
}