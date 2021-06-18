# Execute on external machine and make available to VMs

# https://docs.microsoft.com/en-us/sharepoint/install/hardware-and-software-requirements-2019#links-to-applicable-software

# Config
$prereqsPath = "D:\spfarm\Downloads\sp\prerequisites"
$CSVPath = "D:\spfarm\Scripts\prereqs.csv"

# Read prerequisite URLs from CSV file and download
$prereqs = Import-Csv -LiteralPath $CSVPath -Delimiter "," -Encoding UTF8
foreach ($prereq in $prereqs)
{
    $componentPath = Join-Path -Path $prereqsPath -ChildPath $prereq.Component
    if (-not (Test-Path -Path $componentPath))
    {
        New-Item -ItemType "directory" -Path $componentPath
    }
    Start-BitsTransfer -Source $prereq.URL -Destination $componentPath
    Write-Host "Download compteted $componentPath"
}

# Extract Sync framework MSI from downloaded ZIP for further installation
Expand-Archive -LiteralPath "$prereqsPath\Sync\SyncSetup_en.x64.zip" -DestinationPath "$prereqsPath\Sync\"
Move-Item -LiteralPath "$prereqsPath\Sync\Microsoft Sync Framework\Synchronization.msi" -Destination "$prereqsPath\Sync\"