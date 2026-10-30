# Copy to config\lab.config.psd1 and edit for your host. The local copy is git-ignored.
# The subnets below are documentation ranges (RFC 5737). Replace them with private
# (RFC 1918) ranges that do not overlap your home or work networks.
@{
    # Where the lab lives. An external SSD/USB drive works well.
    LabRoot        = 'D:\HomeLab'

    # Optional extra paths that should point at LabRoot (directory junctions).
    Junctions      = @('C:\HomeLab')

    # Folder holding installer ISOs and OVAs (searched recursively).
    MediaRoot      = 'C:\LabMedia'

    # VMware Workstation install folder.
    VMwareDir      = 'C:\Program Files (x86)\VMware\VMware Workstation'

    # Pin the lab drive to a fixed letter by volume GUID (Get-Partition | Select Guid).
    DriveLetter    = 'D'
    VolumeGuid     = '00000000-0000-0000-0000-000000000000'
    VolumeLabel    = 'HomeLab'

    Networks = @{
        # Lab LAN: targets, DC, attacker eth0, firewall WAN, SIEM
        VMnet1 = @{ Subnet = '192.0.2.0';    Mask = '255.255.255.0'; HostIP = '192.0.2.1';    DhcpStart = '192.0.2.100';    DhcpEnd = '192.0.2.200' }
        # Private segment behind the lab firewall
        VMnet2 = @{ Subnet = '198.51.100.0'; Mask = '255.255.255.0'; HostIP = '198.51.100.1'; DhcpStart = '198.51.100.100'; DhcpEnd = '198.51.100.200' }
    }

    # Nic types: hostonly (VMnet1), hostonly2 (VMnet2), nat (VMnet8)
    VMs = @(
        @{ Name = 'LAB-Kali';      Role = 'Attacker';           Guest = 'debian12-64';       MemMB = 4096; Cpus = 4; DiskGB = 80; Scsi = 'lsilogic';   Media = 'kali-linux-*.iso';          Nics = @('hostonly','nat') }
        @{ Name = 'LAB-Ubuntu';    Role = 'Linux target';       Guest = 'ubuntu-64';         MemMB = 2048; Cpus = 2; DiskGB = 40; Scsi = 'lsilogic';   Media = 'ubuntu-*-server-*.iso';     Nics = @('hostonly') }
        @{ Name = 'LAB-Rocky';     Role = 'RHEL-family target'; Guest = 'rhel9-64';          MemMB = 2048; Cpus = 2; DiskGB = 40; Scsi = 'lsilogic';   Media = 'Rocky-*.iso';               Nics = @('hostonly') }
        @{ Name = 'LAB-Win2019DC'; Role = 'AD / Windows target'; Guest = 'windows2019srv-64'; MemMB = 4096; Cpus = 2; DiskGB = 80; Scsi = 'lsisas1068'; Media = 'Windows_Server_2019*.iso'; Nics = @('hostonly') }
        @{ Name = 'LAB-OPNsense';  Role = 'Lab firewall';       Guest = 'freebsd-64';        MemMB = 2048; Cpus = 2; DiskGB = 20; Scsi = 'lsilogic';   Media = 'OPNsense-*.iso';            Nics = @('hostonly','hostonly2') }
    )

    # SIEM appliance imported from OVA with ovftool (skipped if the OVA is not found).
    Siem = @{ Name = 'LAB-Wazuh'; Media = 'wazuh-*.ova'; Nic = 'VMnet1' }
}
