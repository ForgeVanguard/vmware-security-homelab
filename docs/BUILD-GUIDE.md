# Build guide

The scripts build the scaffolding: folders, networks, empty VMs with installers attached, and the SIEM import. Guest OS installs are done by hand so you learn each one.

## Prerequisites

- Windows 10/11 host with VMware Workstation 17 (includes `vmrun`, `vmware-vdiskmanager`, `vnetlib64` and OVF Tool)
- 32 GB RAM recommended to run the attacker, a target, the DC and the SIEM together
- An external SSD (1–2 TB) or a spare internal disk
- Installer media in one folder: Kali, Ubuntu Server, Rocky Linux minimal, Windows Server 2019 Evaluation, OPNsense, and the Wazuh OVA

## Steps

1. **Configure**: `Copy-Item config\lab.config.example.psd1 config\lab.config.psd1` and edit paths, subnets and the drive GUID (`Get-Partition | Select DriveLetter, Guid`).
2. **Preview**: every script that changes something supports `-WhatIf`.
3. **Folders**: `.\scripts\Initialize-LabFolders.ps1`
4. **Networks** (elevated): `.\scripts\Set-LabNetwork.ps1`
5. **VMs**: `.\scripts\New-LabVMs.ps1`. Rebuild one later with `-Name LAB-Kali -Force`.
6. **Drive letter** (optional, elevated): `.\scripts\Register-LabDriveLetterTask.ps1`
7. **Check**: `.\scripts\Test-LabHost.ps1`
8. **Install guests** in this order:
   1. OPNsense: WAN on VMnet1, LAN on VMnet2
   2. Windows Server 2019: promote to a domain controller for the lab domain
   3. Ubuntu and Rocky targets
   4. Kali
   5. Wazuh: power on, finish first boot, change every default password, then enrol agents
9. After each install, disconnect the ISO, install VMware Tools, and set the static IP from [NETWORK.md](NETWORK.md).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| VM cannot find its ISO or disk | `.\scripts\Repair-VmxPaths.ps1 -Path <LabRoot>\02_VMs` (doubled backslashes in the VMX) |
| External drive came back on another letter | `.\scripts\Set-LabDriveLetter.ps1`, or log off and on so the task runs |
| VMnet1 still on the VMware default subnet | `Set-LabNetwork.ps1` must run elevated, or use Edit > Virtual Network Editor |
| Wazuh not imported | Check the OVA pattern in the config, or File > Open the OVA in Workstation |

## Credentials

Never store lab passwords in this repo. Use a password manager. `.gitignore` excludes common credential file names as a safety net.
