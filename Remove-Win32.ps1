<#
.SYNOPSIS
This script removes all Win32 configuration from driver projects, including .inf files.

.DESCRIPTION
The script recursively searches for .sln, .vcxproj, .inf, and .inx files in the specified repository path. It then removes the Win32 architecture configurations from these files.

.PARAMETER RepositoryPath
Specifies the path to the repository. If not provided, the current location is used.

.EXAMPLE
.\Remove-Win32 -RepositoryPath "D:\source\repos\my-repo"

.NOTES
- The script modifies the files in-place. It is recommended to make a backup of the files before running the script.
#>
[CmdletBinding()]
param (
    [string]$RepositoryPath = (Get-Location)
)

# Get all .sln files recursively
$slnFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.sln" -Recurse

foreach ($slnFile in $slnFiles) {
    # Read the contents of the .sln file
    $slnContent = Get-Content -Path $slnFile.FullName

    # Check if Debug|Win32 configuration already exists
    $debugWin32Exists = $slnContent -match "Debug\|(Win32|x86)"

    # Check if Debug|x64 configuration already exists
    $debugX64Exists = $slnContent -match "Debug\|x64"

    if ($debugWin32Exists) {
        if (-not $debugX64Exists) {
            Write-Warning "Debug|x64 configuration does not exist in $slnFile"
        }
        $slnNewContent = ""
        foreach ($line in $slnContent) {
            $line = $line.TrimEnd()
            if (-not ($line -match "(Debug|Release)\|(Win32|x86)")) {
                $slnNewContent += "$line`r`n"
            }
        }
        # Write the updated contents back to the .sln file
        $slnNewContent | Set-Content -Path $slnFile.FullName -NoNewline
    }
}

# Get all .vcxproj files recursively
$vcxprojFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.vcxproj" -Recurse

foreach ($vcxprojFile in $vcxprojFiles) {
    # Read the contents of the .vcxproj file
    $vcxprojContent = Get-Content -Path $vcxprojFile.FullName

    # Check if Debug|Win32 configuration already exists
    $debugWin32Exists = $vcxprojContent -match "Debug\|Win32"

    if ($debugWin32Exists) {
        $itemsToRemove = @()
        $xml = [xml]$vcxprojContent
        $xml.Project.ChildNodes | ForEach-Object {
            if ($_.Label -eq "ProjectConfigurations") {
                $_.ChildNodes | ForEach-Object {
                    if ($_.Include -match "Win32") {
                        $itemsToRemove += $_
                    }
                }
            }
            if ($_.Label -eq "Globals") {
                $_.ChildNodes | ForEach-Object {
                    if ($_.InnerText -eq "Win32") {
                        $_.InnerText = "x64"
                    }
                    if ($_.InnerText -eq "Win32Proj") {
                        $_.InnerText = "Win64Proj"
                    }
                }
            }
            if ($_.Condition -match "Win32") {
                $itemsToRemove += $_
            }
        }

        foreach ($item in $itemsToRemove) {
            if ($null -ne $item.ParentNode) {
                $item.ParentNode.RemoveChild($item) | Out-Null
            }
        }

        $itemsToRemove = @()

        # Enter ALL the nodes in the XML file recursively
        $stack = New-Object 'System.Collections.Generic.Stack[System.Object]'
        $stack.Push($xml.Project)

        while ($stack.Count -gt 0) {
            $currentNode = $stack.Pop()
            foreach ($childNode in $currentNode.ChildNodes) {
                if ($childNode.NodeType -eq "Element") {
                    if ($childNode.Condition -match '''(\$\(Configuration\)\|)?\$\(Platform\)''==''(.*\|)?Win32''') {
                        $itemsToRemove += $childNode
                    }
                    elseif ($childNode.Condition -match '''\$\(Platform\)''!=''Win32''') {
                        $childNode.RemoveAttribute('Condition') | Out-Null
                    }
                    else {
                        $stack.Push($childNode)
                    }
                }
            }
        }

        foreach ($item in $itemsToRemove) {
            $item.ParentNode.RemoveChild($item) | Out-Null
        }

        # Write the updated contents back to the .vcxproj file
        $xml.Save($vcxprojFile.FullName)
    }
}

# Get all .inf and .inx files recursively
$infFiles = Get-ChildItem -Path $RepositoryPath -Include "*.inf", "*.inx" -Recurse

foreach ($infFile in $infFiles)
{
    # Read the contents of the .inf file
    $infContent = Get-Content -Path $infFile.FullName

    # Check if Win32 architecture is used
    $win32Exists = $infContent -match "x86"

    if ($win32Exists) {
        $infNewContent = ""
        $isManufacturerSection = $false
        $isNTx86Section = $false
        foreach ($line in $infContent) {
            $line = $line.TrimEnd()
            if ($line -match "^\[.*\]") {
                if ($line -match "^\[.*\.NTx86(\.10\.0\.\.\.\d+)?\]") {
                    $isNTx86Section = $true
                }
                elseif ($line -match "^\[SourceDisksNames\.x86\]") {
                    $isNTx86Section = $true
                }
                else {
                    $isNTx86Section = $false
                }
            }
            # Remove NTx86 references from the Manufacturer section
            if ($isManufacturerSection) {
                $line = $line -replace ",\s*NTx86(\.10\.0\.\.\.\d+)?", ""
            }
            # Remove NTx86 sections
            if (-not $isNTx86Section) {
                $infNewContent += "$line`r`n"
            }
            $isManufacturerSection = $line -match "^\[Manufacturer\]"
        }
        # Write the updated contents back to the .inf file
        $infNewContent | Set-Content -Path $infFile.FullName -NoNewline
    }
}