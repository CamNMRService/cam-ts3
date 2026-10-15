# Interactive Directory Cleanup Script (High-Performance .NET Version)

# 1. Get Target Directory (Default: Current Directory)
$defaultPath = (Get-Location).Path
$inputPath = Read-Host "Enter directory to scan [$defaultPath]"
$targetPath = if ([string]::IsNullOrWhiteSpace($inputPath)) { $defaultPath } else { $inputPath }

if (-not (Test-Path -Path $targetPath -PathType Container)) {
    Write-Host "Error: Target directory does not exist: $targetPath" -ForegroundColor Red
    return
}

# 2. Get Regex Pattern (Default: topshimData_2026)
$defaultPattern = "topshimData_2026"
$inputPattern = Read-Host "Enter pattern to match directory names (regex) [$defaultPattern]"
$pattern = if ([string]::IsNullOrWhiteSpace($inputPattern)) { $defaultPattern } else { $inputPattern }

# Validate Regex Syntax
try {
    "" -match $pattern | Out-Null
} catch {
    Write-Host "Error: Invalid regular expression pattern '$pattern'." -ForegroundColor Red
    return
}

# 3. Get Age in Days
$inputDays = Read-Host "Enter age threshold in days"
[int]$days = 0
if (-not [int]::TryParse($inputDays, [ref]$days) -or $days -lt 0) {
    Write-Host "Error: Please enter a valid non-negative integer for days." -ForegroundColor Red
    return
}

$cutoffDate = (Get-Date).AddDays(-$days)

# 4. Fast Scan using .NET EnumerateDirectories
Write-Host "`nScanning '$targetPath' for matching directories..." -ForegroundColor Cyan

$matchingDirs = [System.Collections.Generic.List[PSObject]]::new()

try {
    # .NET enumeration streams string paths instantly without building heavy objects
    $allDirs = [System.IO.Directory]::EnumerateDirectories($targetPath, "*", [System.IO.SearchOption]::AllDirectories)
    
    foreach ($dirPath in $allDirs) {
        $dirName = [System.IO.Path]::GetFileName($dirPath)
        
        # Check regex pattern first (fast string comparison)
        if ($dirName -match$pattern) {
            # Check last write time only if name matches (drastically reduces Disk I/O)
            $lastWrite = [System.IO.Directory]::GetLastWriteTime($dirPath)
            if ($lastWrite -lt $cutoffDate) {$matchingDirs.Add([PSCustomObject]@{
                    FullName      = $dirPath
                    LastWriteTime = $lastWrite
                })
            }
        }
    }
} catch {
    Write-Host "Warning: Some directories could not be accessed due to permission limits." -ForegroundColor Yellow
}

# Handle no matches found
if ($matchingDirs.Count -eq 0) {
    Write-Host "No directories matching pattern '$pattern' older than$days days were found." -ForegroundColor Yellow
    return
}

# Sort deepest paths first to prevent parent/child deletion conflicts
$matchingDirs = $matchingDirs | Sort-Object -Property {$_.FullName.Length } -Descending

# 5. Display Summary Details
Write-Host "`n================ MATCHING DIRECTORIES TO DELETE ================" -ForegroundColor Red
Write-Host " Target Directory : $targetPath"
Write-Host " Regex Pattern    : $pattern"
Write-Host " Cutoff Date      : Items modified before $cutoffDate ($days days old)"
Write-Host " Total Directories: $($matchingDirs.Count)"
Write-Host "----------------------------------------------------------------"
foreach ($dir in $matchingDirs) {
    Write-Host " [DIR] $($dir.FullName) (Last Modified: $($dir.LastWriteTime))"
}
Write-Host "================================================================" -ForegroundColor Red

# 6. Confirmation Prompt (Default: N)
$confirm = Read-Host "Are you sure you want to PERMANENTLY DELETE these directories and all contents? (Y/N) [N]"

if ($confirm -match '^(?i)y(es)?$') {
    Write-Host "`nDeleting directories..." -ForegroundColor Yellow
    foreach ($dir in $matchingDirs) {
        if (Test-Path -Path $dir.FullName) {
            try {
                Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
                Write-Host "Deleted: $($dir.FullName)" -ForegroundColor Green
            } catch {
                Write-Host "Failed to delete $($dir.FullName):$_" -ForegroundColor Red
            }
        }
    }
    Write-Host "`nOperation completed." -ForegroundColor Green
} else {
    Write-Host "`nOperation canceled. No directories were deleted." -ForegroundColor Yellow
}