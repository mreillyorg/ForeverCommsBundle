# Windows PowerShell 5.1+ offline packaging. Zero external tools or online services.
[CmdletBinding()]
param([string]$OutputDir = 'dist')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($OutputDir)) { $OutputDir = Join-Path $root $OutputDir }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$addons = @('ForeverCommsVoice','ForeverGuildComms','ForeverGroupComms')
$versions = @{}
function New-Archive([string]$name, [string[]]$sources) {
    $destination = Join-Path $OutputDir $name
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($destination,[System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in @($sources | Sort-Object -Unique)) {
            $path = [System.IO.Path]::GetFullPath($file)
            if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe path: $path" }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing input: $path" }
            $entry = $path.Substring($root.Length + 1).Replace('\','/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$path,$entry,[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    finally { $zip.Dispose() }
    Write-Host "Created $destination" -ForegroundColor Green
}
function Expand-Sources([string[]]$folders) {
    $all = @()
    foreach ($folder in $folders) {
        $full = Join-Path $root $folder
        if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw "Missing folder: $full" }
        $all += @(Get-ChildItem -LiteralPath $full -File -Recurse -Force | Where-Object { $_.Name -ne '.DS_Store' } | Select-Object -ExpandProperty FullName)
    }
    return $all
}
foreach ($addon in $addons) {
    $toc = Join-Path (Join-Path $root $addon) ($addon + '.toc')
    if (-not (Test-Path $toc -PathType Leaf)) { throw "Missing TOC: $toc" }
    $version = (Select-String -LiteralPath $toc -Pattern '^## Version:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
    if (-not $version) { throw "Missing version in $toc" }
    $versions[$addon] = $version
    if (-not (Test-Path (Join-Path $root "$addon\Media\Icon.tga"))) { throw "Missing icon: $addon" }
    $tocText = Get-Content -LiteralPath $toc -Encoding UTF8
    $expectedIcon = 'Interface\AddOns\' + $addon + '\Media\Icon'
    if (-not (@($tocText | Where-Object { $_.Trim() -ieq ('## IconTexture: ' + $expectedIcon) }).Count -eq 1)) {
        throw "IconTexture missing or invalid for $addon"
    }
    $modules = 0
    foreach ($raw in $tocText) {
        $line = $raw.Trim().TrimStart([char]0xFEFF)
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^[A-Za-z0-9_-]+\.(lua|xml)$') { throw "Unsafe TOC file entry: $line" }
        if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $root $addon) $line) -PathType Leaf)) {
            throw "Missing $addon runtime file: $line"
        }
        $modules++
    }
    if ($modules -eq 0) { throw "No Lua/XML entries in $addon" }
    if ($addon -ne 'ForeverCommsVoice' -and $tocText -notcontains '## Dependencies: ForeverCommsVoice') {
        throw "Missing ForeverCommsVoice dependency in $addon"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root "$addon\Media\ProjectIcon.png"))) { throw "Missing project icon: $addon" }
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
foreach ($addon in $addons) {
    $folders = @($addon, 'install')
    if ($addon -ne 'ForeverCommsVoice') { $folders += 'ForeverCommsVoice' }
    New-Archive ($addon + '-' + $versions[$addon] + '.zip') (Expand-Sources $folders)
}
$all = Expand-Sources ($addons + @('install','tools','.github'))
foreach ($single in @('README.md','PACKAGING.md','package.ps1','package.cmd')) { $all += Join-Path $root $single }
New-Archive ('ForeverComms-Bundle-' + $versions.ForeverGuildComms + '.zip') $all
