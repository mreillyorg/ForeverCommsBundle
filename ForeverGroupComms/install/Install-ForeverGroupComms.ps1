# ForeverGroupComms installer (Windows PowerShell 5.1+).
# Requires the extracted ZIP with the sibling install/ and ForeverCommsVoice.
[CmdletBinding()]
param([string]$GamePath, [switch]$NonInteractive)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$installer = Join-Path -Path $root -ChildPath 'install\Install-ForeverComms.ps1'
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    Write-Host 'Missing shared installer. Extract the ENTIRE ZIP before running this file.' -ForegroundColor Red
    exit 1
}
Write-Host 'ForeverGroupComms uses ForeverCommsVoice for its shared language/accent settings.' -ForegroundColor Cyan
& $installer -GamePath $GamePath -NonInteractive:$NonInteractive -Addons @('ForeverGroupComms')
