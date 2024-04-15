<#
.SYNOPSIS
    Simple checks for validating ownership of files in a repository based on the CODEOWNERS file.

.DESCRIPTION
    This script validates the ownership of files in a repository by checking against the CODEOWNERS file.
    It reads the CODEOWNERS file and retrieves the list of owners for each path specified in the file.
    Then, it checks each file in the repository and verifies if it has an owner assigned.
    If a file does not have an owner, it keeps track of the directories without owners and the number of files and solutions without owners.
    Finally, it prints the summary of files and solutions without owners, as well as the directories without owners.

.PARAMETER RepositoryPath
    The path to the repository to validate.

.EXAMPLE
    .\Assert-Owners -RepositoryPath "D:\source\repos\my-repo"
    Validates the ownership of files in the "my-repo" repository.

.NOTES
    This script requires the CODEOWNERS file to be present in the repository.
    The CODEOWNERS file should follow the GitHub CODEOWNERS syntax.
    This script can only validate paths to directories, not individual files or wildcards.
#>

# TODO: Add support for wildcards in CODEOWNERS file
[CmdletBinding()]
param(
    $RepositoryPath = (Get-Location)
)

$CodeOwnersPath = Join-Path -Path $RepositoryPath -ChildPath ".github\CODEOWNERS"

# Read all paths from CODEOWNERS file while ignoring comments and empty lines
$CodeOwners = Get-Content -Path $CodeOwnersPath | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^/\*' -and  $_ -ne '' } | ForEach-Object { $_ -replace '\s*@.*', '' }

$Files = Get-ChildItem -Path $RepositoryPath -Recurse -File

$Directories = @{}
$FilesWithoutOwnerCount = 0
$SolutionsWithoutOwnerCount = 0
$TotalSolutionCount = ($Files | Where-Object { $_.Name -match '\.sln$' }).Count

# Validate that each file has an owner
$Files | ForEach-Object {
    $FilePath = [System.IO.Path]::GetRelativePath($RepositoryPath, $_.FullName).Replace("\", "/")
    $Owner = $CodeOwners | Where-Object { $FilePath -match $_.TrimStart('/') }
    if (-not $Owner -and $FilePath -match '/') {
        $Directory = $FilePath.Substring(0, $FilePath.LastIndexOf('/'))
        $Directories[$Directory] = $true
        $FilesWithoutOwnerCount++
        if ($FilePath -match '\.sln$') {
            $SolutionsWithoutOwnerCount++
        }
    }
}

# Print directories without owners sorted by name
Write-Host "Files w/o owners: $FilesWithoutOwnerCount ($(($FilesWithoutOwnerCount / $Files.Count).ToString("P2")))"
Write-Host "Total files: $($Files.Count)"
Write-Host "Solutions w/o owners: $SolutionsWithoutOwnerCount ($(($SolutionsWithoutOwnerCount / $TotalSolutionCount).ToString("P2")))"
Write-Host "Total solutions: $TotalSolutionCount"
Write-Host "Directories without owners:"
$Directories.Keys | Sort-Object | ForEach-Object { Write-Host "  $_" }
