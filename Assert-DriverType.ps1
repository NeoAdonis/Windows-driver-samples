<#
.SYNOPSIS
    This script checks for inconsistences between target platforms and driver types in .vcxproj files within a repository.

.DESCRIPTION
    The script takes a repository path as input and searches for all .vcxproj files recursively within the repository.
    It then reads the contents of each .vcxproj file and checks if it is a user mode driver or a driver application.
    If it is a user mode driver, it checks that the driver type is set to "UMDF". Otherwise, it displays the driver type.
    If it is a driver application, it checks that the driver type is not set. Otherwise, it displays the driver type.

.PARAMETER RepositoryPath
    The path to the repository to be checked.

.EXAMPLE
    PS> .\Assert-DriverType -RepositoryPath "D:\source\repos\my-repo"
    Driver1\Driver1.vcxproj : No driver type
    Driver2\Driver2.vcxproj : NOT UMDF - is WDM
    Driver3\App1.vcxproj : App - WDM

.NOTES
    This script assumes that the driver type is specified in the .vcxproj file under the "DriverType" property.
#>

[CmdletBinding()]
param (
    [string]$RepositoryPath = (Get-Location)
)

$vcxprojFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.vcxproj" -Recurse

foreach ($vcxprojFile in $vcxprojFiles) {
    $vcxprojContent = Get-Content -Path $vcxprojFile.FullName

    $isUserModeDriver = $vcxprojContent -match "\bWindowsUserModeDriver10\.0\b"
    $isDriverApplication = $vcxprojContent -match "\bWindowsApplicationForDrivers10\.0\b"

    if ($isUserModeDriver -or $isDriverApplication) {
        $driverType = ""
        $xml = [xml]$vcxprojContent
        $xml.Project.ChildNodes | Where-Object { $_.Name -eq "PropertyGroup" } | ForEach-Object {
            if ($driverType -eq "") {
                $driverTypeNode = $_.ChildNodes | Where-Object { $_.Name -eq "DriverType" } | Select-Object -First 1
                if ($driverTypeNode) {
                    $driverType = $driverTypeNode.InnerText
                }
            }
        }

        $relativePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $vcxprojFile.FullName)

        if ($isUserModeDriver) {
            if ($driverType -eq "") {
                Write-Host "$relativePath : No driver type"
            }
            elseif ($driverType -ne "UMDF") {
                Write-Host "$relativePath : NOT UMDF - is $driverType"
            }
        }

        if ($isDriverApplication) {
            if ($driverType -ne "") {
                Write-Host "$relativePath : App - $driverType"
            }
        }
    }
}
