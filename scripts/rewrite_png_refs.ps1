# Rewrite .png -> .webp string references in Dart source for asset paths
# that fall under directories we converted.
#
# Strategy:
#   Match string literals whose path starts with one of the converted asset
#   subtrees and ends in .png. Path may or may not have the "assets/" prefix
#   (some data files store paths like "images/scenarios/foo.png" and prepend
#   "assets/" at use-site, see lib/data/scenario_data.dart). Dynamic paths
#   with $interpolation are matched by their prefix, so e.g.
#       'assets/images/feelings/$bandFolder/$lId.png'
#   rewrites to
#       'assets/images/feelings/$bandFolder/$lId.webp'
#
#   Things this deliberately does NOT touch:
#     - String literals whose path doesn't start with a converted subtree
#       (e.g. '${tempDir.path}/story_share.png', 'pet_avatar_${ts}.png').
#     - PNG references under assets/avatars/ (we don't convert those).
#
# Safe to run multiple times; already-rewritten files are no-ops.

[CmdletBinding()]
param(
  [string[]]$Roots = @('lib','test','integration_test'),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = 'C:\dev\story-weaver-app'

# Safety bumper: refuse to run if conversion hasn't happened yet, otherwise
# rewriting Dart refs would point them at .webp files that don't exist and
# break the running app. Allow override with -DryRun for inspection.
$webpCount = (Get-ChildItem (Join-Path $repo 'assets') -Recurse -Filter '*.webp' -File -ErrorAction SilentlyContinue | Measure-Object).Count
if ($webpCount -eq 0 -and -not $DryRun) {
  Write-Error "No .webp files found under assets/. Run scripts\convert_assets_to_webp.ps1 first, or pass -DryRun to inspect."
}

# Subtrees whose PNGs we've converted to WebP. Match is on the path inside
# the string literal (forward slashes), with optional "assets/" prefix.
$convertedPrefixes = @(
  'images/archetypes/',
  'images/companions/',
  'images/feelings/',
  'images/scenes/',
  'images/scenarios/',
  'images/orbs/',
  'images/backgrounds/',
  'images/themes/',
  'images/ui/',
  'feelings_faces/',
  'mood_lanterns/'
)

# Build a single alternation regex of the form:
#   (['"])((?:assets/)?(?:images/archetypes/|...|mood_lanterns/)[^'"]*?)\.png(['"])
$alt = ($convertedPrefixes | ForEach-Object { [regex]::Escape($_) }) -join '|'
$pattern = [regex]("(['""])((?:assets/)?(?:$alt)[^'""]*?)\.png(['""])")

$totalEdits   = 0
$filesTouched = 0
$preview      = New-Object 'System.Collections.Generic.List[string]'

foreach ($root in $Roots) {
  $full = Join-Path $repo $root
  if (-not (Test-Path $full)) { continue }
  $dartFiles = Get-ChildItem $full -Recurse -Filter '*.dart' -File
  foreach ($f in $dartFiles) {
    $orig = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($null -eq $orig) { continue }
    $fileEdits = 0
    $new = $pattern.Replace($orig, {
      param($m)
      $script:fileEdits++
      if ($script:preview.Count -lt 20) {
        $script:preview.Add(("    " + $m.Value + "  ->  " + $m.Groups[1].Value + $m.Groups[2].Value + '.webp' + $m.Groups[3].Value))
      }
      return ($m.Groups[1].Value + $m.Groups[2].Value + '.webp' + $m.Groups[3].Value)
    })
    if ($fileEdits -gt 0) {
      $rel = $f.FullName.Substring($repo.Length).TrimStart('\')
      Write-Host ("  {0,3} edits  {1}" -f $fileEdits, $rel)
      $totalEdits  += $fileEdits
      $filesTouched++
      if (-not $DryRun) {
        Set-Content -Path $f.FullName -Value $new -Encoding UTF8 -NoNewline
      }
    }
  }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host ("Files touched: {0}" -f $filesTouched)
Write-Host ("Total edits:   {0}" -f $totalEdits)
if ($DryRun) { Write-Host "(dry-run, no files written)" }

if ($preview.Count -gt 0) {
  Write-Host ""
  Write-Host "Sample of rewrites (first 20):"
  $preview | ForEach-Object { Write-Host $_ }
}
