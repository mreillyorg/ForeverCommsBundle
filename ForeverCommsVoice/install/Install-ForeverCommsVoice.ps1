# ForeverCommsVoice installer (Windows PowerShell 5.1+).
# This addon is the shared library and has no dependencies of its own.
# Requires the extracted ZIP with the sibling install/ folder present.
[CmdletBinding()]
param([string]$GamePath, [switch]$NonInteractive)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$installer = Join-Path -Path $root -ChildPath 'install\Install-ForeverComms.ps1'
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    Write-Host 'Missing shared installer. Extract the ENTIRE ZIP before running this file.' -ForegroundColor Red
    exit 1
}
Write-Host 'ForeverCommsVoice is the shared language/accent library used by Guild and Group Comms.' -ForegroundColor Cyan
& $installer -GamePath $GamePath -NonInteractive:$NonInteractive -Addons @('ForeverCommsVoice')
