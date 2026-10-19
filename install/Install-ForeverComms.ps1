# Forever Comms Windows installer. Supports the full suite or selected addons.
# PowerShell 5.1+. Safe: stages all files before touching the destination,
# makes per-addon backups and attempts to roll back failed updates.
[CmdletBinding()]
param(
    [string]$GamePath,
    [string[]]$Addons = @('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms'),
    [switch]$NonInteractive
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$known = @('ForeverCommsVoice', 'ForeverGuildComms', 'ForeverGroupComms')
$sourceRoot = Split-Path -Path $PSScriptRoot -Parent
$stageRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('ForeverComms-' + [guid]::NewGuid().ToString('N'))
$state = @{}

function Resolve-AddOns([string]$path) {
    $path = [System.IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($path.Trim().Trim('"')))
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Folder not found: $path" }
    $leaf = Split-Path -Path $path -Leaf
    if ($leaf -ieq 'AddOns') {
        if ((Split-Path -Leaf (Split-Path -Parent $path)) -ine 'Interface') { throw 'AddOns must be inside Interface.' }
        return $path
    }
    if ($leaf -ieq 'Interface') { return (Join-Path -Path $path -ChildPath 'AddOns') }
    if (Test-Path -LiteralPath (Join-Path -Path $path -ChildPath '_classic_beta_') -PathType Container) {
        $path = Join-Path -Path $path -ChildPath '_classic_beta_'
    }
    return (Join-Path -Path $path -ChildPath 'Interface\AddOns')
}

function Find-Client {
    $found = @()
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
        foreach ($relative in @('World of Warcraft\_classic_beta_', 'Games\World of Warcraft\_classic_beta_', 'Program Files (x86)\World of Warcraft\_classic_beta_')) {
            $candidate = Join-Path -Path $drive.Root -ChildPath $relative
            if (Test-Path -LiteralPath $candidate -PathType Container) { $found += $candidate }
        }
    }
    $found = @($found | Sort-Object -Unique)
    if ($found.Count -eq 1) { return $found[0] }
    if ($NonInteractive) { throw 'Cannot uniquely detect WoW Forever. Pass -GamePath.' }
    if ($found.Count -gt 1) { Write-Host ('Detected clients: ' + ($found -join '; ')) }
    $entered = Read-Host 'WoW Forever client, Interface, or AddOns directory'
    if ([string]::IsNullOrWhiteSpace($entered)) { throw 'Installation cancelled: no destination selected.' }
    return $entered
}

function Get-RuntimeFiles([string]$source, [string]$name) {
    $toc = $name + '.toc'
    $tocPath = Join-Path -Path $source -ChildPath $toc
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) { throw "Missing manifest: $tocPath" }
    $files = New-Object 'System.Collections.Generic.List[string]'
    $files.Add($toc)
    $iconDeclared = $false
    foreach ($raw in (Get-Content -LiteralPath $tocPath -Encoding UTF8)) {
        $line = $raw.Trim().TrimStart([char]0xFEFF)
        if ($line -match '^## IconTexture:\s*(.+)$') {
            $expected = 'Interface\AddOns\' + $name + '\Media\Icon'
            if ($Matches[1].Trim() -ine $expected) { throw "Unexpected icon path in ${name}: $($Matches[1])" }
            $iconDeclared = $true
        }
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^[A-Za-z0-9_-]+\.(lua|xml)$') { throw "Unsafe TOC file entry in ${name}: $line" }
        if ($files.Contains($line)) { throw "Duplicate TOC file entry in ${name}: $line" }
        $files.Add($line)
    }
    if ($files.Count -lt 2) { throw "No runtime modules in $toc" }
    if ($iconDeclared) { $files.Add('Media\Icon.tga') }
    if (Test-Path -LiteralPath (Join-Path -Path $source -ChildPath 'Bindings.xml') -PathType Leaf) {
        # Blizzard automatically loads this file even without listing it in the TOC.
        $files.Add('Bindings.xml')
    }
    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath (Join-Path -Path $source -ChildPath $file) -PathType Leaf)) {
            throw "${name} is missing required runtime file: $file"
        }
    }
    return $files.ToArray()
}

try {
    $Addons = @($Addons | Select-Object -Unique)
    if ($Addons.Count -eq 0) { throw 'Choose at least one addon to install.' }
    foreach ($name in $Addons) {
        if ($known -cnotcontains $name) { throw "Unknown addon: $name" }
    }
    # Always install Voice before consumers, regardless of input order.
    if ($Addons -contains 'ForeverGuildComms' -or $Addons -contains 'ForeverGroupComms') {
        if ($Addons -notcontains 'ForeverCommsVoice') { $Addons = @('ForeverCommsVoice') + $Addons }
    }
    $ordered = @()
    foreach ($name in $known) { if ($Addons -contains $name) { $ordered += $name } }
    if (-not $GamePath) { $GamePath = Find-Client }
    $dest = Resolve-AddOns $GamePath
    $interfacePath = Split-Path -Path $dest -Parent
    Write-Host ('Installing: ' + ($ordered -join ', ')) -ForegroundColor Cyan
    Write-Host ('Destination: ' + $dest)

    # Resolve and validate ALL install manifests before changing a file.
    New-Item -ItemType Directory -Path $stageRoot -Force -ErrorAction Stop | Out-Null
    foreach ($name in $ordered) {
        $source = Join-Path -Path $sourceRoot -ChildPath $name
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "Missing $name beside install/. Use the full bundle or a current individual ZIP including ForeverCommsVoice."
        }
        $files = @(Get-RuntimeFiles -source $source -name $name)
        $staged = Join-Path -Path $stageRoot -ChildPath $name
        New-Item -ItemType Directory -Path $staged -Force -ErrorAction Stop | Out-Null
        foreach ($file in $files) {
            $output = Join-Path -Path $staged -ChildPath $file
            New-Item -ItemType Directory -Path (Split-Path -Path $output -Parent) -Force -ErrorAction Stop | Out-Null
            Copy-Item -LiteralPath (Join-Path -Path $source -ChildPath $file) -Destination $output -Force -ErrorAction Stop
        }
    }
    # Backup to Interface/AddOnBackups (outside AddOns) to avoid stray addons.
    $backupRoot = Join-Path -Path $interfacePath -ChildPath ('AddOnBackups\ForeverComms-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6))
    New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop | Out-Null
    foreach ($name in $ordered) {
        $state[$name] = @{Target=(Join-Path -Path $dest -ChildPath $name); Backup=(Join-Path -Path $backupRoot -ChildPath $name); HasBackup=$false; Installed=$false}
    }
    try {
        foreach ($name in $ordered) {
            $item = $state[$name]
            if (Test-Path -LiteralPath $item.Target) {
                New-Item -ItemType Directory -Path $backupRoot -Force -ErrorAction Stop | Out-Null
                Move-Item -LiteralPath $item.Target -Destination $item.Backup -ErrorAction Stop
                $item.HasBackup = $true
            }
            Move-Item -LiteralPath (Join-Path -Path $stageRoot -ChildPath $name) -Destination $item.Target -ErrorAction Stop
            $item.Installed = $true
            Write-Host ('Installed ' + $name) -ForegroundColor Green
        }
    }
    catch {
        $original = $_
        foreach ($name in $ordered) {
            $item = $state[$name]
            if ($item.Installed -and (Test-Path -LiteralPath $item.Target)) {
                Remove-Item -LiteralPath $item.Target -Recurse -Force -ErrorAction Continue
            }
            if ($item.HasBackup -and (Test-Path -LiteralPath $item.Backup)) {
                Move-Item -LiteralPath $item.Backup -Destination $item.Target -ErrorAction Continue
            }
        }
        throw $original
    }
    Write-Host 'All selected addons installed. Previous SavedVariables have not been changed.' -ForegroundColor Green
    if (Test-Path -LiteralPath $backupRoot) { Write-Host ('Backups: ' + $backupRoot) }
    Write-Host 'Restart WoW to refresh addon metadata/icons, or use /reload for Lua changes.'
}
catch {
    Write-Host ('INSTALL FAILED: ' + $_) -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
