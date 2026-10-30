#Requires -Version 5.1
<#
.SYNOPSIS
    Fixes doubled backslashes in VMX file paths and reports whether each referenced file exists.
.DESCRIPTION
    A VMX written with escaped paths (C:\\Media\\x.iso) makes Workstation fail to find the
    ISO or disk. This collapses runs of backslashes, keeps a .bak copy of any file it
    changes, and lists every fileName entry with an exists check.
.EXAMPLE
    .\Repair-VmxPaths.ps1 -Path D:\HomeLab\02_VMs -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$Path)

Get-ChildItem -Path $Path -Recurse -Filter *.vmx | ForEach-Object {
    $file = $_.FullName
    $lines = Get-Content -LiteralPath $file
    $fixed = foreach ($l in $lines) { $l -replace '\\{2,}', '\' }
    $changed = ($lines -join "`n") -ne ($fixed -join "`n")

    if ($changed -and $PSCmdlet.ShouldProcess($file, 'Collapse doubled backslashes')) {
        Copy-Item -LiteralPath $file -Destination "$file.bak" -Force
        Set-Content -LiteralPath $file -Value $fixed -Encoding ASCII
        Write-Host "FIXED $file" -ForegroundColor Yellow
    } else {
        Write-Host "OK    $file" -ForegroundColor Green
    }

    $vmDir = Split-Path $file -Parent
    foreach ($line in ($fixed | Where-Object { $_ -match 'fileName\s*=\s*"([^"]+)"' })) {
        $target = ([regex]::Match($line, '"([^"]+)"')).Groups[1].Value
        if ($target -eq 'auto detect') { Write-Host "      $line"; continue }
        $full = if ([IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $vmDir $target }
        Write-Host ("      {0}  exists={1}" -f $line, (Test-Path -LiteralPath $full))
    }
}
