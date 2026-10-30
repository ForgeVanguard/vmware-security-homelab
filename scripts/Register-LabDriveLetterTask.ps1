#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers a logon scheduled task (as SYSTEM) that runs Set-LabDriveLetter.ps1.
.EXAMPLE
    .\Register-LabDriveLetterTask.ps1 -ScriptPath D:\HomeLab\05_Scripts\Set-LabDriveLetter.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'Set-LabDriveLetter.ps1'),
    [string]$TaskName = 'HomeLab-Ensure-DriveLetter'
)
if (-not (Test-Path $ScriptPath)) { throw "Script not found: $ScriptPath" }
$arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
if ($PSCmdlet.ShouldProcess($TaskName, 'Register logon task as SYSTEM')) {
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $trigger   = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Host "Registered $TaskName"
}
