#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures VMware Workstation host-only networks for the lab (VMnet1 and VMnet2).
.DESCRIPTION
    Uses vnetlib to set subnet, mask and DHCP range for each network in the config,
    then sets the host adapter IP. Needs an elevated prompt. The same settings can be
    made by hand in Edit > Virtual Network Editor.
.EXAMPLE
    .\Set-LabNetwork.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$ConfigPath)

Import-Module (Join-Path $PSScriptRoot 'LabCommon.psm1') -Force
$cfg = Import-LabConfig -Path $ConfigPath

$vnetlib = Join-Path $cfg.VMwareDir 'vnetlib64.exe'
if (-not (Test-Path $vnetlib)) { $vnetlib = Join-Path $cfg.VMwareDir 'vnetlib.exe' }
if (-not (Test-Path $vnetlib)) { throw "vnetlib not found under $($cfg.VMwareDir)" }

function Invoke-Vnet([string[]]$VArgs) {
    if ($PSCmdlet.ShouldProcess('vnetlib', ($VArgs -join ' '))) {
        & $vnetlib -- @VArgs | Out-Null
        Write-LabLog ("vnetlib {0} (exit {1})" -f ($VArgs -join ' '), $LASTEXITCODE)
    }
}

Invoke-Vnet @('stop','dhcp')
Invoke-Vnet @('stop','nat')

foreach ($name in ($cfg.Networks.Keys | Sort-Object)) {
    $n = $cfg.Networks[$name]
    $vnet = $name.ToLower()
    if ($vnet -ne 'vmnet1') { Invoke-Vnet @('add','adapter',$vnet) }
    Invoke-Vnet @('set','vnet',$vnet,'addr',$n.Subnet)
    Invoke-Vnet @('set','vnet',$vnet,'mask',$n.Mask)
    Invoke-Vnet @('add','dhcp',$vnet)
    Invoke-Vnet @('set','dhcp',$vnet,'addr',$n.Subnet)
    Invoke-Vnet @('set','dhcp',$vnet,'mask',$n.Mask)
    Invoke-Vnet @('set','dhcp',$vnet,'startaddr',$n.DhcpStart)
    Invoke-Vnet @('set','dhcp',$vnet,'endaddr',$n.DhcpEnd)
    Invoke-Vnet @('update','dhcp',$vnet)
}

Invoke-Vnet @('start','dhcp')
Invoke-Vnet @('start','nat')

foreach ($name in $cfg.Networks.Keys) {
    $n = $cfg.Networks[$name]
    $adapter = Get-NetAdapter -Name "VMware Network Adapter $name" -ErrorAction SilentlyContinue
    if (-not $adapter) { Write-LabLog "adapter for $name not present yet" -Level WARN; continue }
    $prefix = ([Convert]::ToString(([IPAddress]$n.Mask).Address, 2) -replace '0','').Length
    if ($PSCmdlet.ShouldProcess($adapter.Name, "Set IP $($n.HostIP)/$prefix")) {
        Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne $n.HostIP } |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        if (-not (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $n.HostIP -ErrorAction SilentlyContinue)) {
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $n.HostIP -PrefixLength $prefix | Out-Null
        }
        Write-LabLog "$name host IP $($n.HostIP)/$prefix" -Level OK
    }
}

Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -like '*VMnet*' |
    Format-Table InterfaceAlias, IPAddress, PrefixLength -AutoSize
