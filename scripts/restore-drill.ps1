<#
.SYNOPSIS
    Disaster-recovery drill: prove the Postgres backups in Cloudflare R2 actually
    restore. Downloads the latest dump, restores it into a THROWAWAY local
    Postgres (Docker), checks row counts, and reports the measured restore time
    (your real RTO). Closes the "backup restore never tested" gap (FMEA P2 /
    RECOVERY.md §4 / continuity audit).

.DESCRIPTION
    Mirrors .github/workflows/postgres-backup.yml: dumps are named
    story-weaver-pg-YYYY-MM-DD.sql.gz under postgres/ in the R2 bucket.
    Nothing here touches production — it restores into a disposable container.

.PREREQUISITES
    - Docker Desktop running
    - AWS CLI v2 installed (used as the S3 client against R2)
    - R2 credentials, via env vars (same names as the backup workflow) or params:
        R2_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY

.EXAMPLE
    # Using env vars already set:
    pwsh ./scripts/restore-drill.ps1

.EXAMPLE
    # Skip the download and drill a dump you already have:
    pwsh ./scripts/restore-drill.ps1 -DumpFile C:\tmp\story-weaver-pg-2026-06-07.sql.gz
#>
[CmdletBinding()]
param(
    [string]$R2AccountId      = $env:R2_ACCOUNT_ID,
    [string]$R2Bucket         = $env:R2_BUCKET,
    [string]$R2AccessKeyId    = $env:R2_ACCESS_KEY_ID,
    [string]$R2SecretKey      = $env:R2_SECRET_ACCESS_KEY,
    [string]$DumpFile,                       # optional local .sql.gz to skip download
    [int]$Port = 55432,                      # host port for the throwaway DB
    [switch]$KeepContainer                   # leave the container up for inspection
)

$ErrorActionPreference = 'Stop'
$container = 'sw-restore-drill'
$work = Join-Path $env:TEMP 'sw-restore-drill'
$started = Get-Date

function Require-Cmd($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command '$name' not found. See .PREREQUISITES in this script."
    }
}

try {
    Require-Cmd docker
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    # --- 1. Get a dump (.sql.gz) -------------------------------------------
    if (-not $DumpFile) {
        Require-Cmd aws
        foreach ($v in 'R2AccountId','R2Bucket','R2AccessKeyId','R2SecretKey') {
            if (-not (Get-Variable $v).Value) { throw "Missing R2 credential: $v (set the matching env var or pass the param)." }
        }
        $endpoint = "https://$R2AccountId.r2.cloudflarestorage.com"
        $env:AWS_ACCESS_KEY_ID = $R2AccessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $R2SecretKey
        $env:AWS_DEFAULT_REGION = 'auto'
        $env:AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'
        $env:AWS_RESPONSE_CHECKSUM_VALIDATION = 'when_required'

        Write-Host "Finding the latest dump in s3://$R2Bucket/postgres/ ..."
        $keys = aws s3api list-objects-v2 --bucket $R2Bucket --prefix 'postgres/' `
            --endpoint-url $endpoint --query 'Contents[].Key' --output text
        if (-not $keys) { throw "No dumps found under postgres/ in bucket $R2Bucket." }
        $latest = ($keys -split '\s+' | Sort-Object | Select-Object -Last 1)
        Write-Host "Latest dump: $latest"
        $DumpFile = Join-Path $work (Split-Path $latest -Leaf)
        aws s3 cp "s3://$R2Bucket/$latest" $DumpFile --endpoint-url $endpoint
    }
    if (-not (Test-Path $DumpFile)) { throw "Dump file not found: $DumpFile" }

    # --- 2. Decompress .gz -> .sql (no gunzip needed on Windows) -----------
    $sql = Join-Path $work 'restore.sql'
    Write-Host "Decompressing $DumpFile ..."
    $in  = [System.IO.File]::OpenRead($DumpFile)
    $out = [System.IO.File]::Create($sql)
    $gz  = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
    $gz.CopyTo($out); $gz.Dispose(); $out.Dispose(); $in.Dispose()
    $sqlSize = (Get-Item $sql).Length
    Write-Host "Decompressed SQL: $([math]::Round($sqlSize/1KB)) KB"

    # --- 3. Throwaway Postgres -------------------------------------------------
    docker rm -f $container 2>$null | Out-Null
    Write-Host "Starting throwaway Postgres ($container) on port $Port ..."
    docker run -d --name $container -e POSTGRES_PASSWORD=drill -p "${Port}:5432" postgres:alpine | Out-Null
    Write-Host "Waiting for it to accept connections..."
    $ready = $false
    foreach ($i in 1..30) {
        Start-Sleep -Seconds 1
        docker exec $container pg_isready -U postgres 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    }
    if (-not $ready) { throw "Postgres container did not become ready in 30s." }

    # --- 4. Restore -----------------------------------------------------------
    Write-Host "Restoring dump..."
    docker cp $sql "${container}:/restore.sql" | Out-Null
    docker exec $container psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f /restore.sql | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "psql restore reported errors (see output above)." }

    # --- 5. Verify ------------------------------------------------------------
    Write-Host "`n--- Verification ---"
    $tableCount = (docker exec $container psql -U postgres -d postgres -tAc `
        "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';").Trim()
    Write-Host "Public tables restored: $tableCount"
    Write-Host "Row counts (top tables):"
    docker exec $container psql -U postgres -d postgres -c @"
SELECT relname AS table, n_live_tup AS approx_rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC NULLS LAST
LIMIT 15;
"@
    # Headline: the users table should exist.
    $userRows = (docker exec $container psql -U postgres -d postgres -tAc `
        'SELECT count(*) FROM "user";' 2>$null).Trim()
    if ($LASTEXITCODE -eq 0) { Write-Host "`nusers table rows: $userRows" }

    $rto = [math]::Round(((Get-Date) - $started).TotalSeconds)
    Write-Host "`n================================================================"
    Write-Host " RESTORE DRILL PASSED. Measured RTO: ~${rto}s"
    Write-Host " Record this in RECOVERY.md section 4 as your real RTO."
    Write-Host "================================================================"
}
finally {
    if (-not $KeepContainer) {
        docker rm -f $container 2>$null | Out-Null
        Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
    } else {
        Write-Host "`n(-KeepContainer) Left '$container' running on port $Port for inspection."
        Write-Host "Connect: docker exec -it $container psql -U postgres -d postgres"
        Write-Host "Remove when done: docker rm -f $container"
    }
}
