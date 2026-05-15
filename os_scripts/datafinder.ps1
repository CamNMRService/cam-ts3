#Script to find data by searching for a string in just files of a given name (default acqus)
# To find data for a given nucleus use NUC1= <11B> or whatever
# Note that searching for NUC1= <1H> will find proton, cosy , HSQC, HMBC...
# Can optionally add second string - just hit return if not needed.
# Copies directories two levels above the found files to a specified destination.

# Prompt for filename (default: acqus)
$filename = Read-Host "Enter the filename to search for (default: acqus)"
if ([string]::IsNullOrWhiteSpace($filename)) {
    $filename = "acqus"
}

# Prompt for the first search string (required)
$searchString1 = Read-Host "Enter the first string to search for in the file content"
if ([string]::IsNullOrWhiteSpace($searchString1)) {
    Write-Host "First search string is required. Exiting." -ForegroundColor Red
    exit
}

# Prompt for the second search string (optional)
$searchString2 = Read-Host "Enter the second string to search for (optional)"

# Prompt for destination directory
$destinationDir = Read-Host "Enter the destination directory path to copy the directories to"
if ([string]::IsNullOrWhiteSpace($destinationDir)) {
    Write-Host "Destination directory is required. Exiting." -ForegroundColor Red
    exit
}

# Create destination directory if it doesn't exist
if (-not (Test-Path -Path $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Write-Host "Created destination directory: $destinationDir" -ForegroundColor Green
}

# Search logic and copy directories
$foundFiles = Get-ChildItem -Recurse -Filter $filename -File | Where-Object {
    $path = $_.FullName
    $match1 = Select-String -Path $path -Pattern $searchString1 -Quiet
    if (-not $match1) { return $false }

    if (-not [string]::IsNullOrWhiteSpace($searchString2)) {
        $match2 = Select-String -Path $path -Pattern $searchString2 -Quiet
        return $match2
    }

    return $true
}

# Track unique directories to avoid duplicate copies
$copiedDirs = @{}

foreach ($file in $foundFiles) {
    Write-Host "Found: $($file.FullName)" -ForegroundColor Cyan
    
    # Get directory two levels above the found file
    $parentDir = $file.Directory.Parent
    if ($parentDir -ne $null) {
        $dirToCopy = $parentDir.FullName
            
            # Only copy if we haven't already copied this directory
            if (-not $copiedDirs.ContainsKey($dirToCopy)) {
                $destPath = Join-Path -Path $destinationDir -ChildPath $targetDir.Name
                
                try {
                    Copy-Item -Path $dirToCopy -Destination $destPath -Recurse -Force
                    Write-Host "Copied: $dirToCopy -> $destPath" -ForegroundColor Green
                    $copiedDirs[$dirToCopy] = $true
                } catch {
                    Write-Host "Error copying $dirToCopy : $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Warning: Cannot go two levels up from $($file.FullName)" -ForegroundColor Yellow
        }
    }


Write-Host "`nCopy operation completed. Total directories copied: $($copiedDirs.Count)" -ForegroundColor Green
