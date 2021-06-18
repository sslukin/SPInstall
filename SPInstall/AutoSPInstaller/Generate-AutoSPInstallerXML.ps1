#
# Generate-AutoSPInstallerXML
#
#$param_passphrase
#$param_domainname
#$param_password
#$param_dbserver
#$param_pidkey
#$param_appsdomain
#$param_portaldomain

function Generate-AutoSPInstallerXML
{
    param(
        $inputFile,
        $outputFile,
        $passphrase,
        $domainname,
        $password,
        $dbserver,
        $pidkey,
        $appsdomain,
        $portaldomain
    )
    $content = Get-Content -Path $inputFile

    $content = $content.Replace("param_passphrase", $passphrase)
    $content = $content.Replace("param_domainname", $domainname)
    $content = $content.Replace("param_password", $password)
    $content = $content.Replace("param_dbserver", $dbserver)
    $content = $content.Replace("param_pidkey", $pidkey)
    $content = $content.Replace("param_appsdomain", $appsdomain)
    $content = $content.Replace("param_portaldomain", $portaldomain)
    $content | Out-File -FilePath $outputFile -Force
}

Generate-AutoSPInstallerXML `
-inputFile C:\autospinstall.xml `
-outputFile D:\autospinstall.xml `
-passphrase  `
-domainname  `
-password  `
-dbserver  `
-pidkey xxx `
-appsdomain  `
-portaldomain 