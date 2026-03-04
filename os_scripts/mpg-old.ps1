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
$totalFiles = $mpgFiles.Count

Write-Host "Found $totalFiles MPG files to copy" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $mpgFiles.Count; $i++) {
    $file = $mpgFiles[$i]
    $progress = $i + 1
    
    try {
        Write-Host "[$progress/$totalFiles] Copying: $($file.Name)" -ForegroundColor Gray -NoNewline
        Copy-Item -Path $file.FullName -Destination $DestDir -Force
        Write-Host " [SUCCESS]" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "Copy operation completed:" -ForegroundColor Green
Write-Host "  Successfully copied: $successCount files" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "  Errors: $errorCount files" -ForegroundColor Red
}

Read-Host "Press Enter to exit"