#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only health check of the lab host: drive, folders, VMware tools, networks and VMs.
.EXAMPLE
    .\Test-LabHost.ps1
#>
[CmdletBinding()]
param([string]$ConfigPath)

Import-Module (Join-Path $PSScriptRoot 'LabCommon.psm1') -Force
$cfg = Import-LabConfig -Path $ConfigPath
$results = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Check, [bool]$Pass, [string]$Detail = '') {
    $results.Add([pscustomobject]@{ Check = $Check; Result = if ($Pass) { 'PASS' } else { 'FAIL' }; Detail = $Detail })
}

$vol = Get-Volume -DriveLetter $cfg.DriveLetter -ErrorAction SilentlyContinue
Add-Check "Drive $($cfg.DriveLetter): present" ([bool]$vol) ($(if ($vol) { '{0} {1:N0} GB free' -f $vol.FileSystemLabel, ($vol.SizeRemaining / 1GB) }))
Add-Check 'Lab root exists' (Test-Path $cfg.LabRoot) $cfg.LabRoot
foreach ($j in $cfg.Junctions) {
    $item = Get-Item $j -Force -ErrorAction SilentlyContinue
    Add-Check "Junction $j" ($item -and $item.LinkType -eq 'Junction') ($(if ($item) { "$($item.Target)" }))
}

foreach ($exe in 'vmware.exe','vmrun.exe','vmware-vdiskmanager.exe','vnetlib64.exe','OVFTool\ovftool.exe') {
    Add-Check "VMware $exe" (Test-Path (Join-Path $cfg.VMwareDir $exe))
}

foreach ($name in $cfg.Networks.Keys) {
    $want = $cfg.Networks[$name].HostIP
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object InterfaceAlias -like "*$name"
    Add-Check "$name host IP $want" ($ip.IPAddress -contains $want) ("found: " + (($ip.IPAddress) -join ', '))
}

$vmRoot = Join-Path $cfg.LabRoot '02_VMs'
foreach ($vm in @($cfg.VMs) + @($cfg.Siem)) {
    if (-not $vm) { continue }
    $vmx = Join-Path $vmRoot "$($vm.Name)\$($vm.Name).vmx"
    Add-Check "VM $($vm.Name)" (Test-Path $vmx) $vmx
}

Add-Check 'Media folder' (Test-Path $cfg.MediaRoot) $cfg.MediaRoot

$results | Format-Table -AutoSize
$failed = @($results | Where-Object Result -eq 'FAIL').Count
if ($failed) { Write-LabLog "$failed check(s) failed" -Level WARN } else { Write-LabLog 'All checks passed' -Level OK }
