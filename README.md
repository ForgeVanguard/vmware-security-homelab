# VMware Security Homelab

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)
![VMware Workstation](https://img.shields.io/badge/VMware-Workstation%2017-607078?logo=vmware&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

PowerShell scripts and docs for building a portable, isolated security lab on **VMware Workstation**: an attacker box, Linux and Windows targets, an Active Directory domain controller, a lab firewall and a Wazuh SIEM, all on host-only networks.

I built this to practise offensive and defensive work (pentesting, detection engineering, DFIR) on a lab that lives on an external drive and can be torn down and rebuilt from config.

## Lab at a glance

```
                 ┌──────────── VMnet8 (NAT, updates only)
                 │
            ┌────┴────┐
            │  Kali   │  attacker
            └────┬────┘
                 │ VMnet1  host-only lab LAN
  ┌──────────┬───┴──────┬───────────┬─────────────┐
  │          │          │           │             │
Win2019 DC  Ubuntu    Rocky      Wazuh SIEM   OPNsense (WAN)
  (AD)      target    target                      │
                                                  │ VMnet2  private segment
```

| VM | Role | vCPU / RAM / Disk |
| --- | --- | --- |
| LAB-Kali | Attacker | 4 / 4 GB / 80 GB |
| LAB-Win2019DC | Active Directory / Windows target | 2 / 4 GB / 80 GB |
| LAB-Ubuntu | Linux target | 2 / 2 GB / 40 GB |
| LAB-Rocky | RHEL-family target | 2 / 2 GB / 40 GB |
| LAB-OPNsense | Lab firewall (VMnet1 ↔ VMnet2) | 2 / 2 GB / 20 GB |
| LAB-Wazuh | SIEM, imported from the official OVA | per OVA |

## Scripts

| Script | What it does |
| --- | --- |
| `Initialize-LabFolders.ps1` | Creates the lab folder tree, optional junctions, and points Workstation's default VM folder at it |
| `Set-LabNetwork.ps1` | Configures VMnet1/VMnet2 subnets, DHCP ranges and host adapter IPs via `vnetlib` (admin) |
| `New-LabVMs.ps1` | Creates each VM (sparse VMDK, EFI, SATA CD with the right ISO, NICs) and imports the Wazuh OVA with `ovftool` |
| `Repair-VmxPaths.ps1` | Fixes doubled backslashes in VMX paths and reports missing files |
| `Test-LabHost.ps1` | Read-only PASS/FAIL check of drive, junctions, VMware tools, networks and VMs |
| `Set-LabDriveLetter.ps1` | Keeps the external lab drive on a fixed letter, by partition GUID |
| `Register-LabDriveLetterTask.ps1` | Runs the drive-letter fix at logon as a scheduled task |

Everything is driven by `config/lab.config.psd1`. Scripts that change state support `-WhatIf`, are safe to re-run, and never format or wipe a drive.

## Quick start

```powershell
git clone https://github.com/ForgeVanguard/vmware-security-homelab.git
cd vmware-security-homelab
Copy-Item config\lab.config.example.psd1 config\lab.config.psd1   # edit paths, subnets, drive GUID
.\scripts\Initialize-LabFolders.ps1 -WhatIf
.\scripts\Initialize-LabFolders.ps1
.\scripts\Set-LabNetwork.ps1          # elevated
.\scripts\New-LabVMs.ps1
.\scripts\Test-LabHost.ps1
```

Then open each `.vmx` in Workstation and install the guest OS. Full walkthrough: [docs/BUILD-GUIDE.md](docs/BUILD-GUIDE.md). Network plan: [docs/NETWORK.md](docs/NETWORK.md).

## Safety

- Use this lab only against systems you own or are authorized to test.
- Keep targets on host-only networks; never bridge them to a real LAN.
- No credentials, ISOs, or VM disks belong in this repo (see `.gitignore`).

## License

MIT © Steven Drew
