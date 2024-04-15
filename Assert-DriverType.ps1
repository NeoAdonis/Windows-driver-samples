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

# Get all .vcxproj files recursively
$vcxprojFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.vcxproj" -Recurse

foreach ($vcxprojFile in $vcxprojFiles) {
    # Read the contents of the .vcxproj file
    $vcxprojContent = Get-Content -Path $vcxprojFile.FullName

    # Check if project is a user mode driver
    $isUserModeDriver = $vcxprojContent -match "\bWindowsUserModeDriver10\.0\b"
    
    # Check if project is an application for drivers
    $isDriverApplication = $vcxprojContent -match "\bWindowsApplicationForDrivers10\.0\b"

    if ($isUserModeDriver -or $isDriverApplication) {
        $driverType = ""
        $xml = [xml]$vcxprojContent
        $xml.Project.ChildNodes | ForEach-Object {
            if ($_.Name -eq "PropertyGroup" -and $driverType -eq "") {
                $_.ChildNodes | ForEach-Object {
                    if ($_.Name -eq "DriverType") {
                        $driverType = $_.InnerText
                    }
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
