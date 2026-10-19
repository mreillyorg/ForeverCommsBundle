# Installs the entire Forever Comms set to WoW Forever (Windows PowerShell 5.1+).
# Source folder must contain all three sibling addon folders. SavedVariables under WTF are untouched.
[CmdletBinding()]
param([string]$GamePath)
$ErrorActionPreference = 'Stop'
$names = @('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')
$sourceRoot = Split-Path -Parent $PSScriptRoot
$stageRoot = Join-Path $env:TEMP ('ForeverComms-' + [guid]::NewGuid().ToString('N'))
$state = @{}
function Resolve-AddOns([string]$path) {
    $path = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($path.Trim('"')))
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Folder not found: $path" }
    if ((Split-Path $path -Leaf) -eq 'AddOns') { return $path }
    if ((Split-Path $path -Leaf) -eq 'Interface') { return (Join-Path $path 'AddOns') }
    if (Test-Path (Join-Path $path '_classic_beta_')) { $path = Join-Path $path '_classic_beta_' }
    return (Join-Path $path 'Interface\AddOns')
}
try {
    if (-not $GamePath) {
        $guesses = @()
        foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
            foreach ($relative in @('World of Warcraft\_classic_beta_', 'Games\World of Warcraft\_classic_beta_')) {
                $guess = Join-Path $drive.Root $relative
                if (Test-Path -LiteralPath $guess -PathType Container) { $guesses += $guess }
            }
        }
        $guesses = @($guesses | Sort-Object -Unique)
        if ($guesses.Count -eq 1) { $GamePath = $guesses[0] }
        else {
            Write-Host 'Enter WoW Forever _classic_beta_ path (or Interface/AddOns path).' -ForegroundColor Cyan
            if ($guesses.Count -gt 1) { Write-Host ('Detected: ' + ($guesses -join '; ')) }
            $GamePath = Read-Host 'WoW Forever folder'
            if ([string]::IsNullOrWhiteSpace($GamePath)) { throw 'No client directory chosen.' }
        }
    }
    $dest = Resolve-AddOns $GamePath
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    # Verify every source folder before touching any existing installation.
    foreach ($name in $names) {
        $source = Join-Path $sourceRoot $name
        $toc = Join-Path $source ($name + '.toc')
        if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) { throw "Missing source: $toc" }
        Copy-Item -LiteralPath $source -Destination $stageRoot -Recurse -Force -ErrorAction Stop
        $staged = Join-Path $stageRoot $name
        if (-not (Test-Path -LiteralPath (Join-Path $staged ($name+'.toc')))) { throw "Invalid staged folder: $name" }
    }
    $backupRoot = Join-Path $dest ('AddOnBackups\ForeverComms-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    foreach ($name in $names) {
        $target = Join-Path $dest $name
        $state[$name] = @{ Target=$target; Backup=(Join-Path $backupRoot $name); HasBackup=$false; Installed=$false }
    }
    try {
        foreach ($name in $names) {
            $item = $state[$name]
            if (Test-Path -LiteralPath $item.Target) {
                Move-Item -LiteralPath $item.Target -Destination $item.Backup -ErrorAction Stop
                $item.HasBackup = $true
            }
            Move-Item -LiteralPath (Join-Path $stageRoot $name) -Destination $item.Target -ErrorAction Stop
            $item.Installed = $true
            Write-Host ('Installed ' + $name) -ForegroundColor Green
        }
    }
    catch {
        $installError = $_
        foreach ($name in $names) {
            $item = $state[$name]
            if (-not $item) { continue }
            if ($item.Installed -and (Test-Path -LiteralPath $item.Target)) {
                Remove-Item -LiteralPath $item.Target -Recurse -Force
            }
            if ($item.HasBackup -and (Test-Path -LiteralPath $item.Backup)) {
                Move-Item -LiteralPath $item.Backup -Destination $item.Target
            }
        }
        throw $installError
    }
    Write-Host ('Installed all three addons into ' + $dest) -ForegroundColor Green
    Write-Host ('Previous addon folders, if any, were moved to ' + $backupRoot)
    Write-Host 'Previous SavedVariables files were not modified.'
}
catch { Write-Host $_ -ForegroundColor Red; exit 1 }
finally { if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force } }
