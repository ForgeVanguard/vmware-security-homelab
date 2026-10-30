#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for the homelab build scripts.
#>

function Write-LabLog {
    param([Parameter(Mandatory)][string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $color = @{ INFO = 'Gray'; WARN = 'Yellow'; ERROR = 'Red'; OK = 'Green' }[$Level]
    Write-Host ('[{0}] {1,-5} {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message) -ForegroundColor $color
}

function Import-LabConfig {
    [CmdletBinding()]
    param([string]$Path)
    if (-not $Path) {
        $configDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'config'
        $Path = Join-Path $configDir 'lab.config.psd1'
        if (-not (Test-Path $Path)) { $Path = Join-Path $configDir 'lab.config.example.psd1' }
    }
    if (-not (Test-Path $Path)) { throw "Lab config not found: $Path" }
    Write-LabLog "Using config $Path"
    Import-PowerShellDataFile -Path $Path
}

function Find-LabMedia {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Pattern)
    if (-not (Test-Path $Root)) { return $null }
    $hit = Get-ChildItem -Path $Root -Recurse -File -Filter $Pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($hit) { $hit.FullName } else { $null }
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Export-ModuleMember -Function Write-LabLog, Import-LabConfig, Find-LabMedia, Test-IsAdmin
