# Interactive script to list directories created within X days
# The script will prompt for directory path and number of days
# Results will be displayed in date order and saved to a text file

# Get current directory to use as default
$currentDir = (Get-Location).Path

# Ask for directory path with current directory as default
$dirPath = Read-Host -Prompt "Enter directory path [$currentDir]"
if ([string]::IsNullOrWhiteSpace($dirPath)) {
    $dirPath = $currentDir
}

# Ask for number of days
$days = Read-Host -Prompt "Enter number of days to look back"

# Validate days input is a number
if (-not [int]::TryParse($days, [ref]$null)) {
    Write-Host "Invalid input for days. Please enter a number." -ForegroundColor Red
    exit
}

# Calculate the cutoff date
$cutoffDate = (Get-Date).AddDays(-[int]$days)

Write-Host "Searching for directories created in the last $days days in: $dirPath" -ForegroundColor Cyan

# Get directories created after the cutoff date, sorted by creation time
$results = Get-ChildItem -Path $dirPath -Directory | 
    Where-Object { $_.CreationTime -ge $cutoffDate } | 
    Sort-Object CreationTime |
    Select-Object FullName, CreationTime

# Display results
if ($results.Count -eq 0) {
    Write-Host "No directories found created within the last $days days." -ForegroundColor Yellow
} else {
    Write-Host "Found $($results.Count) directories:" -ForegroundColor Green
    $results | Format-Table -AutoSize
    
    # Create output file name based on current date/time
    $outputFile = Join-Path $currentDir "RecentDirs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    # Save to text file
    $results | Format-Table -AutoSize | Out-File -FilePath $outputFile
    
    Write-Host "Results saved to: $outputFile" -ForegroundColor Green
}