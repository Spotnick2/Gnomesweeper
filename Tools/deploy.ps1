<#
    deploy.ps1 - Copy Gnomesweeper into the Forever AddOns folder.

    The repo keeps "## Version: @project-version@" for the packager; the deployed
    copy gets "dev". The repo copy is never modified.

    Usage:
        pwsh Tools/deploy.ps1
        pwsh Tools/deploy.ps1 -AddOnsPath "D:\...\_classic_beta_\Interface\AddOns"
#>

param(
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $AddOnsPath)) { Write-Error "AddOns path not found: $AddOnsPath"; exit 1 }

$dest = Join-Path $AddOnsPath "Gnomesweeper"
Write-Host "Deploying Gnomesweeper -> $dest" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$files = @("Gnomesweeper.toc", "LICENSE") + (Get-ChildItem -LiteralPath $RepoRoot -File |
    Where-Object { $_.Extension -in ".lua", ".xml" } | Select-Object -ExpandProperty Name)
# The client reads the TOC and finds new files (Bindings.xml, a texture) only at start:
# say so when this deploy brings either (review of #58).
$restart = @()
$tocDest = Join-Path $dest "Gnomesweeper.toc"
$tocWas = if (Test-Path -LiteralPath $tocDest) { Get-Content -LiteralPath $tocDest -Raw } else { $null }
foreach ($f in $files) {
    $src = Join-Path $RepoRoot $f
    if (-not (Test-Path -LiteralPath (Join-Path $dest $f))) { $restart += $f }
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

# Libs: the embedded libraries (#40), mirrored exactly, so a library dropped from
# the repo doesn't linger where the client would still load it.
$libsSrc = Join-Path $RepoRoot "Libs"
$libsDest = Join-Path $dest "Libs"
if (Test-Path -LiteralPath $libsDest) { Remove-Item -LiteralPath $libsDest -Recurse -Force }
if (Test-Path -LiteralPath $libsSrc) {
    Copy-Item -LiteralPath $libsSrc -Destination $libsDest -Recurse -Force
    Write-Host "  Libs\  ($((Get-ChildItem -LiteralPath $libsDest -Recurse -File).Count) files)"
}

# Media: only what the client loads (TGA/BLP textures, OGG sounds), never PNG masters.
$media = Join-Path $dest "Media"
New-Item -ItemType Directory -Force -Path $media | Out-Null
$art = Get-ChildItem -LiteralPath (Join-Path $RepoRoot "Media") -File |
    Where-Object { $_.Extension -in ".tga", ".blp", ".ogg" }
foreach ($t in $art) {
    if (-not (Test-Path -LiteralPath (Join-Path $media $t.Name))) { $restart += "Media\$($t.Name)" }
    Copy-Item -LiteralPath $t.FullName -Destination (Join-Path $media $t.Name) -Force
}
Write-Host "  Media\  ($($art.Count) files)"
# Media removed from the repo must not linger either: a stale texture would
# hide a missing-asset bug in game. Only the types copied above are pruned.
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
if ($tocWas -ne $null -and $tocWas -ne (Get-Content -LiteralPath $tocDest -Raw)) { $restart += "Gnomesweeper.toc (changed)" }
if ($restart.Count -gt 0) {
    Write-Host "RESTART the client (a /reload won't see these): $($restart -join ', ')" -ForegroundColor Red
} else {
    Write-Host "Changed files only: /reload is enough." -ForegroundColor Yellow
}
Write-Host "In game:  /console scriptErrors 1   then   /gsweep" -ForegroundColor Green
