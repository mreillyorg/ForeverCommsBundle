# Local Forever Comms release build for Windows.
#
# BigWigsMods/packager is the authoritative release path for GitHub. This builds the
# equivalent archive locally so a release can be previewed and checked without pushing
# a tag.
#
# This is a launcher, not a second implementation. The builder is tools/package.py, which
# reads the same root .pkgmeta that BigWigs reads, so there is one source of truth for
# what ships. An earlier version of this script kept its own parallel inclusion rules and
# drifted from .pkgmeta; that is deliberately not repeated.
#
# Requires Python 3. If that is unacceptable, run the build through GitHub Actions
# instead -- the workflow needs nothing installed locally.
[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$Source,
    [string]$Version
)
$ErrorActionPreference = 'Stop'

$python = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found) { $python = $found.Source; break }
}
if (-not $python) {
    Write-Host 'Python 3 was not found on PATH.' -ForegroundColor Red
    Write-Host 'Install it from https://www.python.org/downloads/ (tick "Add to PATH"),'
    Write-Host 'or let the GitHub Actions workflow build the release instead.'
    exit 1
}

$builder = Join-Path $PSScriptRoot 'tools\package.py'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    Write-Host "Missing builder: $builder" -ForegroundColor Red
    Write-Host 'Extract the ENTIRE suite before building.'
    exit 1
}

$arguments = @($builder)
if ($Source) { $arguments += '--source' }
if ($OutputDir) { $arguments += @('--output', $OutputDir) }
if ($Version) { $arguments += @('--version', $Version) }

& $python @arguments
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Packaging failed. See the errors above.' -ForegroundColor Red
    exit $LASTEXITCODE
}

# Validate the bundle against the same contract the CI workflow applies.
# check_bigwigs_bundle.py reads .release relative to the current directory, so skip it
# when the output was redirected rather than reporting a misleading result.
if (-not $Source -and -not $OutputDir) {
    Push-Location $PSScriptRoot
    try {
        & $python (Join-Path $PSScriptRoot 'tools\check_bigwigs_bundle.py')
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Bundle structure check failed.' -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
    finally { Pop-Location }
}
elseif ($OutputDir) {
    Write-Host "Skipped the structure check: it reads .release, not $OutputDir." -ForegroundColor Yellow
}
Write-Host 'Done.' -ForegroundColor Green
