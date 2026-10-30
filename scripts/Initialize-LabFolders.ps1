#Requires -Version 5.1
<#
.SYNOPSIS
    Creates the lab folder tree and optional directory junctions.
.DESCRIPTION
    Safe to re-run. Never formats or wipes anything: it only creates folders that are
    missing and junctions that do not exist yet.
.EXAMPLE
    .\Initialize-LabFolders.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$ConfigPath)

Import-Module (Join-Path $PSScriptRoot 'LabCommon.psm1') -Force
$cfg = Import-LabConfig -Path $ConfigPath

$folders = '00_Docs','01_Media','02_VMs','03_Shared','04_Tools','05_Scripts','06_Exports'
foreach ($f in $folders) {
    $p = Join-Path $cfg.LabRoot $f
    if (Test-Path $p) { Write-LabLog "exists  $p"; continue }
    if ($PSCmdlet.ShouldProcess($p, 'Create folder')) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-LabLog "created $p" -Level OK
    }
}

foreach ($j in $cfg.Junctions) {
    if (Test-Path $j) {
        $item = Get-Item $j -Force
        if ($item.LinkType -eq 'Junction') { Write-LabLog "junction ok $j -> $($item.Target)" }
        else { Write-LabLog "$j exists and is not a junction; leaving it alone" -Level WARN }
        continue
    }
    if ($PSCmdlet.ShouldProcess($j, "Create junction to $($cfg.LabRoot)")) {
        New-Item -ItemType Junction -Path $j -Target $cfg.LabRoot | Out-Null
        Write-LabLog "junction $j -> $($cfg.LabRoot)" -Level OK
    }
}

# Point VMware Workstation's default VM folder at the lab
$vmPath = Join-Path $cfg.LabRoot '02_VMs'
$prefs = Join-Path $env:APPDATA 'VMware\preferences.ini'
if ((Test-Path $prefs) -and $PSCmdlet.ShouldProcess($prefs, "Set prefvmx.defaultVMPath = $vmPath")) {
    $lines = @(Get-Content $prefs | Where-Object { $_ -notmatch '^prefvmx\.defaultVMPath' })
    $lines += ('prefvmx.defaultVMPath = "{0}"' -f $vmPath)
    Set-Content -Path $prefs -Value $lines -Encoding ASCII
    Write-LabLog "VMware default VM path -> $vmPath" -Level OK
}
