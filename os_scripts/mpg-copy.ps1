# Ask user for source and destination directories
Write-Host "MPG File Copy Script" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

$SourceDir = Read-Host "Enter source directory path"
$DestDir = Read-Host "Enter destination directory path"
Write-Host ""

# Check if source directory exists
if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory '$SourceDir' does not exist."
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $DestDir)) {
    Write-Host "Creating destination directory: $DestDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
}

Write-Host "Searching for MPG files in: $SourceDir" -ForegroundColor Cyan
Write-Host "Copying to: $DestDir" -ForegroundColor Cyan
Write-Host ""

# Find all .mpg files recursively (case insensitive)
$mpgFiles = Get-ChildItem -Path $SourceDir -Filter "*.mpg" -Recurse -File

if ($mpgFiles.Count -eq 0) {
    Write-Host "No MPG files found in the source directory." -ForegroundColor Yellow
    exit 0
}

$successCount = 0
$errorCount = 0
$skippedCount = 0

foreach ($file in $mpgFiles) {
    $destFile = Join-Path $DestDir $file.Name
    $shouldCopy = $false
    $status = ""
    
    if (-not (Test-Path $destFile)) {
        $shouldCopy = $true
        $status = "NEW"
    } else {
        $sourceLastWrite = $file.LastWriteTime
        $destLastWrite = (Get-Item $destFile).LastWriteTime
        
        if ($sourceLastWrite -gt $destLastWrite) {
            $shouldCopy = $true
            $status = "NEWER"
        } else {
            $shouldCopy = $false
            $status = "SKIPPED (up to date)"
        }
    }
    
    if ($shouldCopy) {
        try {
            Write-Host "[$status] Copying: $($file.Name)" -ForegroundColor Yellow
            Write-Host "  From: $($file.FullName)" -ForegroundColor Gray
            Write-Host "  To:   $destFile" -ForegroundColor Gray
            
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            
            Write-Host "  ✓ Success" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        }
        Write-Host ""
    } else {
        Write-Host "[$status] $($file.Name)" -ForegroundColor DarkYellow
        $skippedCount++
    }
}

Write-Host ""
Write-Host "Copy operation completed:" -ForegroundColor Green
Write-Host "  Successfully copied: $successCount files" -ForegroundColor Green
Write-Host "  Skipped (up to date): $skippedCount files" -ForegroundColor DarkYellow
if ($errorCount -gt 0) {
    Write-Host "  Errors: $errorCount files" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
