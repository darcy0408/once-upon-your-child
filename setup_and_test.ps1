#!/usr/bin/env pwsh
param()

# Set error action preference
$ErrorActionPreference = "Continue"

Write-Host "=== STEP 1: Checking Flask Backend ===" -ForegroundColor Cyan

# Test if backend is running
$backendRunning = $false
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "Flask backend is already running!" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
    $backendRunning = $true
} catch {
    Write-Host "Flask backend is NOT running. Starting it..." -ForegroundColor Yellow
    
    # Start the backend process
    Start-Process -FilePath "C:\dev\story-weaver-app\backend\.venv\Scripts\python.exe" `
        -ArgumentList "C:\dev\story-weaver-app\backend\app.py" `
        -WorkingDirectory "C:\dev\story-weaver-app" `
        -WindowStyle Hidden
    
    Write-Host "Backend process started. Waiting 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check health again
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "Flask backend is now running!" -ForegroundColor Green
        Write-Host "Response: $($response.Content)" -ForegroundColor Green
        $backendRunning = $true
    } catch {
        Write-Host "Flask backend health check still failed after starting" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# STEP 2: Check if Flutter web build exists
Write-Host "`n=== STEP 2: Checking Flutter Web Build ===" -ForegroundColor Cyan

$flutterIndexPath = "C:\dev\story-weaver-app\build\web\index.html"
if (Test-Path $flutterIndexPath) {
    Write-Host "Flutter web build found at: $flutterIndexPath" -ForegroundColor Green
} else {
    Write-Host "Flutter web build NOT found. Building now..." -ForegroundColor Yellow
    Set-Location "C:\dev\story-weaver-app"
    flutter build web --release
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Flutter build completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Flutter build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }
}

# STEP 3: Check if port 8080 is in use
Write-Host "`n=== STEP 3: Starting Flutter Web Server ===" -ForegroundColor Cyan

$port8080InUse = $false
try {
    $netstat = netstat -ano | Select-String ":8080"
    if ($netstat) {
        Write-Host "Port 8080 is already in use" -ForegroundColor Green
        $port8080InUse = $true
    }
} catch {
    Write-Host "Could not check port 8080 status" -ForegroundColor Yellow
}

if (-not $port8080InUse) {
    Write-Host "Starting web server on port 8080..." -ForegroundColor Yellow
    Start-Process -FilePath "C:\dev\story-weaver-app\backend\.venv\Scripts\python.exe" `
        -ArgumentList "-m http.server 8080 --directory C:\dev\story-weaver-app\build\web" `
        -WindowStyle Hidden
    Write-Host "Web server started" -ForegroundColor Green
}

# STEP 4: Verify both servers
Write-Host "`n=== STEP 4: Verifying Both Servers ===" -ForegroundColor Cyan
Start-Sleep -Seconds 5

Write-Host "Checking Flask backend (port 5000)..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "✓ Flask backend is running" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "✗ Flask backend health check failed" -ForegroundColor Red
}

Write-Host "`nChecking Flutter web server (port 8080)..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 3 -ErrorAction Stop
    Write-Host "✓ Flutter web server is running" -ForegroundColor Green
    Write-Host "Response status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter web server check failed" -ForegroundColor Red
}

# STEP 5: Run comprehensive quality check
Write-Host "`n=== STEP 5: Running Comprehensive Quality Check ===" -ForegroundColor Cyan
Set-Location "C:\dev\story-weaver-app"
$env:MOCK_TESTING_MODE = "false"

Write-Host "Starting quality check (this may take 5-10 minutes)..." -ForegroundColor Yellow
if (Test-Path "C:\dev\story-weaver-app\run_comprehensive_quality_check.py") {
    & "C:\dev\story-weaver-app\backend\.venv\Scripts\python.exe" run_comprehensive_quality_check.py
} else {
    Write-Host "Quality check script not found at C:\dev\story-weaver-app\run_comprehensive_quality_check.py" -ForegroundColor Red
}

# STEP 6: Run cross-browser tests
Write-Host "`n=== STEP 6: Running Cross-Browser Tests ===" -ForegroundColor Cyan
if (Test-Path "C:\dev\story-weaver-app\test_cross_browser.py") {
    & "C:\dev\story-weaver-app\backend\.venv\Scripts\python.exe" test_cross_browser.py
} else {
    Write-Host "Cross-browser test script not found at C:\dev\story-weaver-app\test_cross_browser.py" -ForegroundColor Red
}

Write-Host "`n=== ALL STEPS COMPLETED ===" -ForegroundColor Cyan
