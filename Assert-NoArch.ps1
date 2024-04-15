<#
.SYNOPSIS
    Retrieves solution files that do not contain a specific architecture configuration.

.DESCRIPTION
    This script searches for solution files in a specified repository path and identifies the ones that do not contain a specific architecture configuration, such as "Debug|ARM64".
    It then outputs the list of solution files that do not have the specified architecture configuration.

.PARAMETER RepositoryPath
    The path to the repository where the solution files are located.

.PARAMETER Architecture
    The architecture configuration to search for. By default, it is set to "ARM64".

.OUTPUTS
    The script outputs the list of solution files that do not have the specified architecture configuration.

.EXAMPLE
    .\Assert-NoArch.ps1 -RepositoryPath "D:\source\repos\my-repo" -Architecture "x64"
    Retrieves solution files in the "D:\source\repos\my-repo" repository that do not have "x64" configurations.

#>

[CmdletBinding()]
param (
    [string]$RepositoryPath = (Get-Location),
    [string]$Architecture = "ARM64"
)

$slnFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.sln" -Recurse

# Retrieve all solution files that do NOT contain a "Debug|<arch>" or "Release|<arch>" configuration
$slnFilesNoArch = $slnFiles | Select-Object -Property FullName | ForEach-Object {
    $slnContent = Get-Content -Path $_.FullName
    $archExists = $slnContent -match "(Debug|Release)\|$Architecture\b"
    if (-not $archExists) {
        $_.FullName
    }
}

Write-Host "Solutions with no $Architecture configuration: $($slnFilesNoArch.Count) ($(($slnFilesNoArch.Count / $slnFiles.Count).ToString("P2")) of all solutions)"
$slnFilesNoArch | ForEach-Object {
    Write-Host "  $([System.IO.Path]::GetRelativePath($RepositoryPath, $_))"
}
