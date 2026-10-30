# Lab network design

All addresses here are documentation ranges (RFC 5737). Pick your own private ranges that do not overlap your home or work LAN and put them in `config/lab.config.psd1`.

| VMware network | Mode | Example subnet | Host IP | DHCP | Purpose |
| --- | --- | --- | --- | --- | --- |
| VMnet1 | Host-only | 192.0.2.0/24 | 192.0.2.1 | .100–.200 | Lab LAN: targets, domain controller, attacker eth0, firewall WAN, SIEM |
| VMnet2 | Host-only | 198.51.100.0/24 | 198.51.100.1 | .100–.200 | Private segment behind the lab firewall |
| VMnet8 | NAT | VMware default | .1 | VMware DHCP | Outbound updates for the attacker VM only |

## NIC assignments

| VM | ethernet0 | ethernet1 |
| --- | --- | --- |
| LAB-Kali | VMnet1 | NAT (updates and tool downloads) |
| LAB-Ubuntu | VMnet1 | – |
| LAB-Rocky | VMnet1 | – |
| LAB-Win2019DC | VMnet1 | – |
| LAB-OPNsense | VMnet1 (WAN / lab side) | VMnet2 (LAN) |
| LAB-Wazuh | VMnet1 | – |

## Suggested static addresses

| Host | Address |
| --- | --- |
| Windows Server 2019 DC | 192.0.2.10 |
| Ubuntu target | 192.0.2.20 |
| Rocky target | 192.0.2.21 |
| Wazuh | 192.0.2.30 |
| Kali | 192.0.2.50 |

## Isolation rules

- Targets stay on host-only networks. Never bridge a target VM to a real LAN.
- Only the attacker VM gets NAT, and only for package updates.
- Snapshot before any destructive exercise.
- Only test systems you own or have written permission to test.
