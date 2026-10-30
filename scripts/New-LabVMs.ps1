#Requires -Version 5.1
<#
.SYNOPSIS
    Creates empty VMware Workstation VMs (sparse disk + installer ISO attached) from the lab config.
.DESCRIPTION
    Builds each VM folder, a growable VMDK and a VMX file with EFI, SATA CD-ROM and the
    NICs from the config. Optionally imports the SIEM appliance OVA with ovftool.
    Does not power anything on and does not install guest operating systems.
.PARAMETER Name
    Only build these VMs (default: all in the config).
.PARAMETER Force
    Delete and rebuild a VM that already exists (stops it first).
.EXAMPLE
    .\New-LabVMs.ps1 -WhatIf
.EXAMPLE
    .\New-LabVMs.ps1 -Name LAB-Kali -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath,
    [string[]]$Name,
    [switch]$Force,
    [switch]$SkipSiem
)

Import-Module (Join-Path $PSScriptRoot 'LabCommon.psm1') -Force
$cfg = Import-LabConfig -Path $ConfigPath

$vmRoot  = Join-Path $cfg.LabRoot '02_VMs'
$vdisk   = Join-Path $cfg.VMwareDir 'vmware-vdiskmanager.exe'
$vmrun   = Join-Path $cfg.VMwareDir 'vmrun.exe'
$ovftool = Join-Path $cfg.VMwareDir 'OVFTool\ovftool.exe'
if (-not (Test-Path $vdisk)) { throw "vmware-vdiskmanager.exe not found under $($cfg.VMwareDir)" }
if (-not (Test-Path $vmRoot)) { throw "$vmRoot is missing. Run Initialize-LabFolders.ps1 first." }

function ConvertTo-VmxLines {
    param($Vm, [string]$IsoPath)
    $l = [System.Collections.Generic.List[string]]::new()
    $l.AddRange([string[]]@(
        '.encoding = "UTF-8"'
        'config.version = "8"'
        'virtualHW.version = "21"'
        'virtualHW.productCompatibility = "hosted"'
        "displayName = `"$($Vm.Name)`""
        "guestOS = `"$($Vm.Guest)`""
        "memsize = `"$($Vm.MemMB)`""
        "numvcpus = `"$($Vm.Cpus)`""
        "cpuid.coresPerSocket = `"$($Vm.Cpus)`""
        'firmware = "efi"'
        'uefi.secureBoot.enabled = "FALSE"'
        "nvram = `"$($Vm.Name).nvram`""
        "extendedConfigFile = `"$($Vm.Name).vmxf`""
        'scsi0.present = "TRUE"'
        "scsi0.virtualDev = `"$($Vm.Scsi)`""
        'scsi0:0.present = "TRUE"'
        "scsi0:0.fileName = `"$($Vm.Name).vmdk`""
        'scsi0:0.deviceType = "scsi-hardDisk"'
        'sata0.present = "TRUE"'
        'sata0:0.present = "TRUE"'
        'sata0:0.deviceType = "cdrom-image"'
    ))
    if ($IsoPath) {
        # VMX accepts single backslashes; doubling them breaks the path (see Repair-VmxPaths.ps1)
        $l.Add("sata0:0.fileName = `"$IsoPath`"")
        $l.Add('sata0:0.startConnected = "TRUE"')
    } else {
        $l.Add('sata0:0.fileName = "auto detect"')
        $l.Add('sata0:0.startConnected = "FALSE"')
    }
    $i = 0
    foreach ($nic in $Vm.Nics) {
        $l.Add("ethernet$i.present = `"TRUE`"")
        $l.Add("ethernet$i.virtualDev = `"e1000e`"")
        $l.Add("ethernet$i.addressType = `"generated`"")
        switch ($nic) {
            'hostonly'  { $l.Add("ethernet$i.connectionType = `"custom`""); $l.Add("ethernet$i.vnet = `"VMnet1`"") }
            'hostonly2' { $l.Add("ethernet$i.connectionType = `"custom`""); $l.Add("ethernet$i.vnet = `"VMnet2`"") }
            'nat'       { $l.Add("ethernet$i.connectionType = `"nat`"") }
            default     { throw "Unknown NIC type '$nic' on $($Vm.Name)" }
        }
        $i++
    }
    $l.AddRange([string[]]@(
        'usb.present = "TRUE"'
        'usb_xhci.present = "TRUE"'
        'sound.present = "FALSE"'
        'svga.graphicsMemoryKB = "262144"'
        'tools.syncTime = "TRUE"'
        'pciBridge0.present = "TRUE"'
        'pciBridge4.present = "TRUE"'
        'pciBridge4.virtualDev = "pcieRootPort"'
        'pciBridge4.functions = "8"'
        'vmci0.present = "TRUE"'
        'hpet0.present = "TRUE"'
        'powerType.powerOff = "soft"'
        'powerType.powerOn = "soft"'
        'powerType.suspend = "soft"'
        'powerType.reset = "soft"'
    ))
    $l
}

$targets = $cfg.VMs
if ($Name) { $targets = $targets | Where-Object { $Name -contains $_.Name } }

foreach ($vm in $targets) {
    $dir  = Join-Path $vmRoot $vm.Name
    $vmx  = Join-Path $dir "$($vm.Name).vmx"
    $vmdk = Join-Path $dir "$($vm.Name).vmdk"
    Write-LabLog "=== $($vm.Name) ($($vm.Role)) ==="

    if (Test-Path $vmx) {
        if (-not $Force) { Write-LabLog "exists, skipping (use -Force to rebuild)" -Level WARN; continue }
        if ($PSCmdlet.ShouldProcess($dir, 'Stop and delete existing VM')) {
            if (Test-Path $vmrun) { & $vmrun -T ws stop $vmx hard 2>$null | Out-Null; Start-Sleep -Seconds 2 }
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
    }

    $iso = Find-LabMedia -Root $cfg.MediaRoot -Pattern $vm.Media
    if ($iso) { Write-LabLog "media $iso" } else { Write-LabLog "no media matching $($vm.Media); CD left empty" -Level WARN }

    if ($PSCmdlet.ShouldProcess($vmx, "Create $($vm.DiskGB) GB disk and VMX")) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & $vdisk -c -t 0 -s "$($vm.DiskGB)GB" -a $vm.Scsi $vmdk | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $vmdk)) { throw "vmware-vdiskmanager failed for $($vm.Name) (exit $LASTEXITCODE)" }
        Set-Content -LiteralPath $vmx -Value (ConvertTo-VmxLines -Vm $vm -IsoPath $iso) -Encoding ASCII
        Write-LabLog "created $vmx" -Level OK
    }
}

if (-not $SkipSiem -and $cfg.Siem -and (-not $Name -or $Name -contains $cfg.Siem.Name)) {
    $s = $cfg.Siem
    $dir = Join-Path $vmRoot $s.Name
    $vmx = Join-Path $dir "$($s.Name).vmx"
    $ova = Find-LabMedia -Root $cfg.MediaRoot -Pattern $s.Media
    if (Test-Path $vmx) {
        Write-LabLog "$($s.Name) already imported" -Level WARN
    } elseif (-not $ova) {
        Write-LabLog "no OVA matching $($s.Media); skipping SIEM import" -Level WARN
    } elseif (-not (Test-Path $ovftool)) {
        Write-LabLog "ovftool not found; import $ova with File > Open in Workstation" -Level WARN
    } elseif ($PSCmdlet.ShouldProcess($vmx, "Import $ova")) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & $ovftool --acceptAllEulas "--name=$($s.Name)" --diskMode=thin $ova $vmx
        if (Test-Path $vmx) {
            $text = Get-Content -LiteralPath $vmx -Raw
            $text = $text -replace 'ethernet0\.connectionType\s*=\s*"[^"]*"', 'ethernet0.connectionType = "custom"'
            if ($text -notmatch 'ethernet0\.vnet') { $text = $text.TrimEnd() + "`r`nethernet0.vnet = `"$($s.Nic)`"`r`n" }
            Set-Content -LiteralPath $vmx -Value $text -Encoding ASCII
            Write-LabLog "imported $($s.Name), NIC0 -> $($s.Nic)" -Level OK
        } else {
            Write-LabLog "ovftool finished but $vmx is missing" -Level ERROR
        }
    }
}

Write-LabLog 'Done. Open each .vmx in Workstation (File > Open) and install the guest OS.' -Level OK
