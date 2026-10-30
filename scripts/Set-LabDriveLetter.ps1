#Requires -Version 5.1
<#
.SYNOPSIS
    Keeps an external lab drive on the same drive letter so VM paths never break.
.DESCRIPTION
    Finds the partition by GUID and assigns the configured letter. It will not take the
    letter from a different volume. Logs to LabRoot\05_Scripts\logs (or %TEMP% if the
    drive is not mounted yet). Exit codes: 0 ok, 1 error / not found, 2 letter in use.
.EXAMPLE
    .\Set-LabDriveLetter.ps1 -VolumeGuid 00000000-0000-0000-0000-000000000000 -DriveLetter D
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath,
    [string]$VolumeGuid,
    [ValidatePattern('^[D-Z]$')][string]$DriveLetter
)

$cfgFile = $ConfigPath
if (-not $cfgFile) { $cfgFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'config\lab.config.psd1' }
if ((-not $VolumeGuid -or -not $DriveLetter) -and (Test-Path $cfgFile)) {
    $cfg = Import-PowerShellDataFile $cfgFile
    if (-not $VolumeGuid)  { $VolumeGuid  = $cfg.VolumeGuid }
    if (-not $DriveLetter) { $DriveLetter = $cfg.DriveLetter }
}
if (-not $VolumeGuid -or -not $DriveLetter) { throw 'Provide -VolumeGuid and -DriveLetter or a config file.' }
$VolumeGuid = $VolumeGuid.Trim('{}')

$logDir = Join-Path $env:TEMP 'HomeLab'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'drive-letter.log'
function Log([string]$m) { Add-Content -Path $log -Value "$(Get-Date -Format o) $m"; Write-Verbose $m }

try {
    $part = Get-Partition | Where-Object { $_.Guid -eq "{$VolumeGuid}" } | Select-Object -First 1
    if (-not $part) { Log "Partition {$VolumeGuid} not found"; exit 1 }
    if ($part.DriveLetter -eq $DriveLetter) { Log "Already ${DriveLetter}:"; exit 0 }

    $conflict = Get-Partition -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if ($conflict -and $conflict.Guid -ne "{$VolumeGuid}") { Log "${DriveLetter}: is held by another volume; not taking it"; exit 2 }

    if ($PSCmdlet.ShouldProcess("Partition {$VolumeGuid}", "Assign ${DriveLetter}:")) {
        if ($part.DriveLetter) {
            Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -AccessPath "$($part.DriveLetter):\" -ErrorAction SilentlyContinue
            Log "Removed $($part.DriveLetter):"
        }
        Set-Partition -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -NewDriveLetter $DriveLetter
        Log "Assigned ${DriveLetter}:"
    }
    exit 0
} catch {
    Log $_.Exception.Message
    exit 1
}
