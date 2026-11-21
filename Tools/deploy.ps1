<#
    deploy.ps1 - Copy Gnomesweeper into the Forever AddOns folder.

    The repo keeps "## Version: @project-version@" for the packager; the deployed
    copy gets "dev". The repo copy is never modified.

    The glass material is the embedded LibGlass-1.0 (#71). The packager fetches it
    into Libs\LibGlass-1.0 (.pkgmeta externals); for a dev copy this script hands
    that job to the LibGlass checkout's own deploy.ps1, which checks the checkout,
    copies only the shipped files and prints its commit. The checkout is
    $env:LIBGLASS, else ..\LibGlass.

    The developer probe, Tools\GnomesweeperProbe (#87), is a ForeverProbe module and
    never packaged: -Probe deploys it too, -ProbeOnly just it, the ForeverProbe
    checkout first ($env:FOREVERPROBE, else ..\ForeverProbe; its GUIDE section 6).
    Deploy it only for a test session the owner is running: _forever_ is the live client.

    Usage:
        pwsh Tools/deploy.ps1
        pwsh Tools/deploy.ps1 -Probe        # ...and GnomesweeperProbe (/fp sweep)
        pwsh Tools/deploy.ps1 -ProbeOnly    # just GnomesweeperProbe
        pwsh Tools/deploy.ps1 -AddOnsPath "D:\...\_forever_\Interface\AddOns"
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns",
    [switch]$Probe,
    [switch]$ProbeOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $AddOnsPath)) { Write-Error "AddOns path not found: $AddOnsPath"; exit 1 }

$ForeverProbe = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else { Join-Path (Split-Path -Parent $RepoRoot) "ForeverProbe" }
if (-not [System.IO.Path]::IsPathRooted($ForeverProbe)) { $ForeverProbe = Join-Path $RepoRoot $ForeverProbe }

function Deploy-Probe {
    # The host first: GnomesweeperProbe has ## Dependencies: ForeverProbe, so without
    # it the client loads no probe at all.
    if (-not (Test-Path -LiteralPath (Join-Path $ForeverProbe "Tools\deploy.ps1"))) {
        Write-Error "ForeverProbe checkout not found at $ForeverProbe (clone github.com/Spotnick2/ForeverProbe there, or set `$env:FOREVERPROBE)"
        exit 1
    }
    & pwsh -NoProfile -File (Join-Path $ForeverProbe "Tools\deploy.ps1") -AddOnsPath $AddOnsPath
    if ($LASTEXITCODE -ne 0) { Write-Error "ForeverProbe deploy refused; GnomesweeperProbe was not touched"; exit 1 }
    $src = Join-Path $RepoRoot "Tools\GnomesweeperProbe"
    $dest = Join-Path $AddOnsPath "GnomesweeperProbe"
    Write-Host "Deploying GnomesweeperProbe -> $dest" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    # The TOC and Lua only, mirrored: a file dropped from the probe doesn't linger.
    $probeFiles = Get-ChildItem -LiteralPath $src -File | Where-Object { $_.Extension -in ".toc", ".lua" }
    foreach ($f in $probeFiles) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $f.Name) -Force
        Write-Host "  $($f.Name)"
    }
    $names = $probeFiles | Select-Object -ExpandProperty Name
    Get-ChildItem -LiteralPath $dest -File | Where-Object { $names -notcontains $_.Name } | ForEach-Object {
        Write-Host "  removing stale $($_.Name)" -ForegroundColor DarkYellow
        Remove-Item -LiteralPath $_.FullName -Force
    }
}

if ($ProbeOnly) {
    Deploy-Probe
    Write-Host ""
    Write-Host "/reload in game to load it, then /fp sweep for the probe's commands." -ForegroundColor Yellow
    exit 0
}

# A relative $env:LIBGLASS is from the repo root, as in the tests.
$LibGlass = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
if (-not [System.IO.Path]::IsPathRooted($LibGlass)) { $LibGlass = Join-Path $RepoRoot $LibGlass }
if (-not (Test-Path -LiteralPath (Join-Path $LibGlass "Tools\deploy.ps1"))) {
    Write-Error "LibGlass checkout not found at $LibGlass (clone github.com/Spotnick2/LibGlass there, or set `$env:LIBGLASS)"
    exit 1
}

# The tag .pkgmeta pins is what the packager will ship. A dev checkout elsewhere
# is legitimate (trying a library change before a pin bump), but an in-game check
# then tests something the release won't carry: say so.
# Only the Libs/LibGlass-1.0 entry's pin, as tests/fetch_libglass.sh reads it.
$pin = $null; $inLib = $false
foreach ($line in Get-Content -LiteralPath (Join-Path $RepoRoot ".pkgmeta")) {
    if ($line -match '^  Libs/LibGlass-1\.0:') { $inLib = $true; continue }
    if ($inLib -and $line -match '^\s{0,2}\S') { break }
    if ($inLib -and $line -match '^\s+(commit|tag):\s*(\S+)\s*$') { $pin = $Matches[2]; break }
}
$want = $null; $head = $null; $dirty = $null
try {
    $want = (git -C $LibGlass rev-parse --verify --quiet "$pin^{commit}" 2>$null)
    $head = (git -C $LibGlass rev-parse HEAD 2>$null)
    $dirty = (git -C $LibGlass status --porcelain 2>$null)
} catch { }
if (-not $pin -or -not $want -or $want -ne $head -or $dirty) {
    Write-Host "WARNING: the LibGlass checkout is not at the .pkgmeta pin ($pin)$(if ($dirty) { ', or has uncommitted changes' }):" -ForegroundColor Yellow
    Write-Host "this deploy tests a library the release won't ship." -ForegroundColor Yellow
}

# The library first: its deploy checks the checkout and may refuse, and a refusal
# must leave the deployed addon as it was (a new TOC naming a library that never
# arrived would load no glass at all).
& pwsh -NoProfile -File (Join-Path $LibGlass "Tools\deploy.ps1") -Addon Gnomesweeper -AddOnsPath $AddOnsPath
if ($LASTEXITCODE -ne 0) { Write-Error "LibGlass deploy refused; Gnomesweeper was not touched"; exit 1 }

$dest = Join-Path $AddOnsPath "Gnomesweeper"
Write-Host "Deploying Gnomesweeper -> $dest" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$files = @("Gnomesweeper.toc", "LICENSE") + (Get-ChildItem -LiteralPath $RepoRoot -File |
    Where-Object { $_.Extension -in ".lua", ".xml" } | Select-Object -ExpandProperty Name)
foreach ($f in $files) {
    $src = Join-Path $RepoRoot $f
    if ($f -like "*.toc") {
        (Get-Content -LiteralPath $src -Raw) -replace '## Version: @project-version@', '## Version: dev' |
            Set-Content -LiteralPath (Join-Path $dest $f) -NoNewline
    } else {
        Copy-Item -LiteralPath $src -Destination (Join-Path $dest $f) -Force
    }
    Write-Host "  $f"
}
# A file removed from the repo must not linger where the client finds it.
Get-ChildItem -LiteralPath $dest -File | Where-Object { $files -notcontains $_.Name } | ForEach-Object {
    Write-Host "  removing stale $($_.Name)" -ForegroundColor DarkYellow
    Remove-Item -LiteralPath $_.FullName -Force
}

# Libs: the vendored libraries (#40), mirrored exactly, so a library dropped from
# the repo doesn't linger where the client would still load it. Libs\LibGlass-1.0
# is LibGlass's deploy's (above), never touched here.
$libsSrc = Join-Path $RepoRoot "Libs"
$libsDest = Join-Path $dest "Libs"
$glassLib = "LibGlass-1.0"
if (Test-Path -LiteralPath $libsDest) {
    Get-ChildItem -LiteralPath $libsDest | Where-Object { $_.Name -ne $glassLib } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
}
if (Test-Path -LiteralPath $libsSrc) {
    New-Item -ItemType Directory -Force -Path $libsDest | Out-Null
    $vendored = Get-ChildItem -LiteralPath $libsSrc | Where-Object { $_.Name -ne $glassLib }
    foreach ($lib in $vendored) { Copy-Item -LiteralPath $lib.FullName -Destination $libsDest -Recurse -Force }
    Write-Host "  Libs\  ($(($vendored | Get-ChildItem -Recurse -File).Count) vendored files, and LibGlass-1.0)"
}

# Locales (#36): the language files, mirrored exactly like Libs.
$locSrc = Join-Path $RepoRoot "Locales"
$locDest = Join-Path $dest "Locales"
if (Test-Path -LiteralPath $locSrc) {
    if (Test-Path -LiteralPath $locDest) { Remove-Item -LiteralPath $locDest -Recurse -Force }
    Copy-Item -LiteralPath $locSrc -Destination $locDest -Recurse -Force
    Write-Host "  Locales\  ($((Get-ChildItem -LiteralPath $locDest -File).Count) files)"
}

# Media: only what the client loads (TGA/BLP textures, OGG sounds), never PNG masters.
$media = Join-Path $dest "Media"
New-Item -ItemType Directory -Force -Path $media | Out-Null
$art = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Media") -File |
    Where-Object { $_.Extension -in ".tga", ".blp", ".ogg" }
foreach ($t in $art) {
    Copy-Item -LiteralPath $t.FullName -Destination (Join-Path $media $t.Name) -Force
}
Write-Host "  Media\  ($($art.Count) files)"
# Media removed from the repo must not linger either: a stale texture would
# hide a missing-asset bug in game. Only the types copied above are pruned. This
# also clears the material's old copies (#71: they ship in Libs\LibGlass-1.0 now).
$names = $art | Select-Object -ExpandProperty Name
Get-ChildItem -LiteralPath $media -File | Where-Object { $_.Extension -in ".tga", ".blp", ".ogg" -and $names -notcontains $_.Name } | ForEach-Object {
    Write-Host "  removing stale Media\$($_.Name)" -ForegroundColor DarkYellow
    Remove-Item -LiteralPath $_.FullName -Force
}

# Every file the TOC lists must be in the deployed copy: a TOC entry in a folder
# this script doesn't copy would otherwise only show as a load error in game.
$missing = Get-Content -LiteralPath (Join-Path $RepoRoot "Gnomesweeper.toc") |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -match '\.(lua|xml)$' -and $_ -notmatch '^#' } |
    Where-Object { -not (Test-Path -LiteralPath (Join-Path $dest $_)) }
if ($missing) {
    $missing | ForEach-Object { Write-Host "  MISSING in the deployed copy: $_" -ForegroundColor Red }
    Write-Error "Deploy is incomplete: the TOC lists files that weren't copied."
    exit 1
}
Write-Host "  every TOC file is in place" -ForegroundColor DarkGray

Write-Host ""
# /reload loads everything a deploy brings: new files, new textures, a changed TOC
# (re-measured 2026-11-16, GuildSpy #97; porting guide section 5; #93).
if ($Probe) { Deploy-Probe }
Write-Host "/reload in game to load it." -ForegroundColor Yellow
Write-Host "In game:  /console scriptErrors 1   then   /gsweep$(if ($Probe) { '   (probe: /fp sweep, its lines in /fp)' })" -ForegroundColor Green
