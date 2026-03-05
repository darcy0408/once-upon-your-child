param(
  [switch]$ClearUnitTestAssets
)

$ErrorActionPreference = "Stop"

function Stop-MatchingFlutterToolProcesses {
  $processes = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq "dart.exe" -and
    $_.CommandLine -match "flutter_tools\.snapshot" -and
    (
      $_.CommandLine -match ' test ' -or
      $_.CommandLine -match ' analyze ' -or
      $_.CommandLine -match ' build '
    )
  }

  $count = 0
  foreach ($proc in $processes) {
    try {
      Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
      $count++
    } catch {
      Write-Warning "Could not stop PID $($proc.ProcessId): $($_.Exception.Message)"
    }
  }

  return $count
}

Write-Output "Cleaning Flutter test/build lock sources..."
$stopped = Stop-MatchingFlutterToolProcesses
Write-Output "Stopped flutter tool processes: $stopped"

if ($ClearUnitTestAssets) {
  $assetsPath = Join-Path $PSScriptRoot "..\build\unit_test_assets"
  $resolved = [System.IO.Path]::GetFullPath($assetsPath)

  if (Test-Path $resolved) {
    Remove-Item -Recurse -Force $resolved
    Write-Output "Removed: $resolved"
  } else {
    Write-Output "No unit test assets directory found: $resolved"
  }
}

Write-Output "Done."
