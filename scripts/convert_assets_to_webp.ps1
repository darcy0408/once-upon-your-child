# Convert illustration PNGs in assets/ to WebP using cwebp.
#
# - Backs up every original PNG to assets/.png-backup/<same path>.
# - Encodes WebP next to original, then deletes the .png on success.
# - Skips files <50KB (compression overhead, not worth it).
# - Skips files already converted (idempotent).
# - Use -DryRun to see what would happen with no side effects.
# - Use -Quality to override the default 85.
#
# Asset path declarations in pubspec.yaml are directory-based, so renaming
# foo.png -> foo.webp inside a declared directory is auto-picked up by
# Flutter. No pubspec change is needed. The companion script
# rewrite_png_refs.ps1 updates Dart-side 'foo.png' string references.
#
# Restore everything by copying assets/.png-backup/* back over assets/.

[CmdletBinding()]
param(
  [switch]$DryRun,
  [int]$Quality = 85,
  [int]$MinBytes = 50KB
)

$ErrorActionPreference = 'Stop'

# Directories whose PNGs are illustration content (lossy-safe). UI chrome
# included because WebP supports alpha and these are still drawn raster art,
# not pixel-perfect icons.
$Targets = @(
  'assets\images\archetypes',
  'assets\images\companions',
  'assets\images\feelings',
  'assets\images\scenes',
  'assets\images\scenarios',
  'assets\images\orbs',
  'assets\images\backgrounds',
  'assets\images\themes',
  'assets\images\ui',
  'assets\feelings_faces',
  'assets\mood_lanterns'
)

$repo       = 'C:\dev\story-weaver-app'
$backupRoot = Join-Path $repo 'assets\.png-backup'

$wingetDir = "C:\Users\Darcy\AppData\Local\Microsoft\WinGet\Packages\Google.Libwebp_Microsoft.Winget.Source_8wekyb3d8bbwe\libwebp-1.6.0-windows-x64\bin"
$cwebpExe = Join-Path $wingetDir "cwebp.exe"

$cwebp = $null
if (Test-Path $cwebpExe) {
  $cwebp = $cwebpExe
} else {
  $cmd = Get-Command cwebp -ErrorAction SilentlyContinue
  if ($cmd) {
    $cwebp = $cmd.Definition
  }
}

if (-not $cwebp -and -not $DryRun) {
  Write-Error "cwebp not found. Install libwebp from https://developers.google.com/speed/webp/download and add its bin/ to PATH."
}

$pngs = foreach ($t in $Targets) {
  $full = Join-Path $repo $t
  if (Test-Path $full) {
    Get-ChildItem $full -Recurse -Filter '*.png' -File
  }
}

# Filter: skip small files, skip backup tree if it ever appears in scan.
$pngs = $pngs | Where-Object {
  $_.Length -ge $MinBytes -and $_.FullName -notlike "$backupRoot*"
}

$totalIn  = ($pngs | Measure-Object Length -Sum).Sum
Write-Host ("Scanned {0} PNG(s) totaling {1:N1} MB" -f $pngs.Count, ($totalIn/1MB))
if ($pngs.Count -eq 0) { return }

$converted = 0
$skipped   = 0
$totalOut  = 0L
$failed    = New-Object System.Collections.Generic.List[string]

foreach ($f in $pngs) {
  $rel       = $f.FullName.Substring($repo.Length).TrimStart('\')
  $webpPath  = [System.IO.Path]::ChangeExtension($f.FullName, '.webp')
  $backupDst = Join-Path $backupRoot $rel

  if (Test-Path $webpPath) {
    $skipped++
    continue
  }

  if ($DryRun) {
    Write-Host ("[dry-run] {0,8:N0} KB  {1}" -f ($f.Length/1KB), $rel)
    continue
  }

  $backupDir = Split-Path $backupDst -Parent
  if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  }
  Copy-Item $f.FullName $backupDst -Force

  # cwebp emits to stderr regardless of success; -quiet suppresses progress.
  # Temporarily disable ErrorActionPreference Stop to prevent stderr progress from triggering NativeCommandError
  $origPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'

  & $cwebp -quiet -q $Quality -o $webpPath -- $f.FullName 2>$null

  $ErrorActionPreference = $origPreference

  if (-not (Test-Path $webpPath) -or (Get-Item $webpPath).Length -eq 0) {
    $failed.Add($rel)
    # Roll back: keep the original, drop any partial webp.
    if (Test-Path $webpPath) { Remove-Item $webpPath -Force }
    continue
  }

  $outSize = (Get-Item $webpPath).Length
  $totalOut += $outSize
  $converted++

  # Delete the original PNG; backup tree is the rollback safety net.
  Remove-Item $f.FullName -Force

  if (($converted % 25) -eq 0) {
    Write-Host ("  converted {0}/{1} ..." -f $converted, $pngs.Count)
  }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host ("Converted:  {0}" -f $converted)
Write-Host ("Skipped:    {0} (already had .webp)" -f $skipped)
Write-Host ("Failed:     {0}" -f $failed.Count)
if ($failed.Count -gt 0) {
  Write-Host "Failures:"
  $failed | ForEach-Object { Write-Host "  $_" }
}
if ($converted -gt 0) {
  Write-Host ("Before:    {0,10:N1} MB" -f ($totalIn/1MB))
  Write-Host ("After:     {0,10:N1} MB" -f ($totalOut/1MB))
  Write-Host ("Saved:     {0,10:N1} MB ({1:N0}% reduction)" -f (($totalIn-$totalOut)/1MB), (100*(1 - $totalOut/$totalIn)))
}
Write-Host ""
Write-Host "Originals backed up to: $backupRoot"
Write-Host "To roll back, run:  Copy-Item -Recurse -Force '$backupRoot\assets\*' '$repo\assets\'"
