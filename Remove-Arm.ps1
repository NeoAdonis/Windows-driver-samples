<#
.SYNOPSIS
This script removes all ARM configuration from driver projects, including .inf files.

.DESCRIPTION
The script recursively searches for .sln, .vcxproj, .inf, and .inx files in the specified repository path. It then removes the ARM architecture configurations from these files.

.PARAMETER RepositoryPath
Specifies the path to the repository. If not provided, the current location is used.

.EXAMPLE
Remove-Arm.ps1 -RepositoryPath "D:\source\repos\my-repo"
This example runs the script on the specified folder path "D:\source\repos\my-repo".

.NOTES
- The script modifies the files in-place. It is recommended to make a backup of the files before running the script.
#>
param (
    [string]$RepositoryPath = (Get-Location)
)

# Get all .sln files recursively
$slnFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.sln" -Recurse

foreach ($slnFile in $slnFiles) {
    # Read the contents of the .sln file
    $slnContent = Get-Content -Path $slnFile.FullName

    # Check if Debug|Arm (NOT Debug|Arm64) configuration already exists
    $debugArmExists = $slnContent -match "Debug\|ARM(?!64)"

    if ($debugArmExists) {
        $slnNewContent = ""
        foreach ($line in $slnContent) {
            $line = $line.TrimEnd()
            if (-not ($line -match "(Debug|Release)\|ARM(?!64)")) {
                $slnNewContent += "$line`r`n"
            }
        }
        # Write the updated contents back to the .sln file
        $slnNewContent | Set-Content -Path $slnFile.FullName -NoNewline
        #$slnNewContent | Set-Content -Path "test_out.sln"
    }
}

# Get all .vcxproj files recursively
$vcxprojFiles = Get-ChildItem -Path $RepositoryPath -Filter "*.vcxproj" -Recurse

foreach ($vcxprojFile in $vcxprojFiles) {
    # Read the contents of the .vcxproj file
    $vcxprojContent = Get-Content -Path $vcxprojFile.FullName

    # Check if Debug|Win32 configuration already exists
    $debugArmExists = $vcxprojContent -match "Debug\|ARM(?!64)"

    if ($debugArmExists) {
        $itemsToRemove = @()
        $xml = [xml]$vcxprojContent
        $xml.Project.ChildNodes | ForEach-Object {
            if ($_.Label -eq "ProjectConfigurations") {
                $_.ChildNodes | ForEach-Object {
                    if ($_.Include -match "ARM(?!64)") {
                        $itemsToRemove += $_
                    }
                }
            }
            if ($_.Label -eq "Globals") {
                $_.ChildNodes | ForEach-Object {
                    if ($_.InnerText -eq "ARM") {
                        $_.InnerText = "ARM64"
                    }
                }
            }
            if ($_.Condition -match "ARM(?!64)") {
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
                    if ($childNode.Condition -match '''(\$\(Configuration\)\|)?\$\(Platform\)''==''(.*\|)?ARM''') {
                        $itemsToRemove += $childNode
                    }
                    else {
                        $stack.Push($childNode)
                    }
                }
            }
        }

        foreach ($item in $itemsToRemove) {
            $item.ParentNode.RemoveChild($item) | Out-Null
            #$conditionSet.Add($item.Condition) | Out-Null
        }

        # Write the updated contents back to the .vcxproj file
        $xml.Save($vcxprojFile.FullName)
        #$xml.Save('test_out.vcxproj')
    }
}

# Get all .inf and .inx files recursively
$infFiles = Get-ChildItem -Path $RepositoryPath -Include "*.inf", "*.inx" -Recurse

foreach ($infFile in $infFiles)
{
    # Read the contents of the .inf file
    $infContent = Get-Content -Path $infFile.FullName

    # Check if ARM architecture is used
    $armExists = $infContent -match "ARM(?!64)"

    if ($armExists) {
        $infNewContent = ""
        $isManufacturerSection = $false
        $isNTARMSection = $false
        foreach ($line in $infContent) {
            $line = $line.TrimEnd()
            if ($line -match "^\[.*\]") {
                if ($line -match "^\[.*\.ARM(\.10\.0\.\.\.\d+)?\]") {
                    $isNTARMSection = $true
                }
                elseif ($line -match "^\[SourceDisksNames\.ARM\]") {
                    $isNTARMSection = $true
                }
                else {
                    $isNTARMSection = $false
                }
            }
            # Remove NTARM references from the Manufacturer section
            if ($isManufacturerSection) {
                $line = $line -replace ",\s*ARM(\.10\.0\.\.\.\d+)?", ""
            }
            # Remove NTARM sections
            if (-not $isNTARMSection) {
                $infNewContent += "$line`r`n"
            }
            $isManufacturerSection = $line -match "^\[Manufacturer\]"
        }
        # Write the updated contents back to the .inf file
        $infNewContent | Set-Content -Path $infFile.FullName -NoNewline
        #$infNewContent | Set-Content -Path "test_out.inf"
    }
}


#git restore .\smartcrd\