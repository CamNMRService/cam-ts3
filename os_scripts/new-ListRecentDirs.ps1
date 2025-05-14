# Enhanced interactive script to list directories created/modified within X days
# The script allows selection of the date property to use for comparison

# Get current directory to use as default
$currentDir = (Get-Location).Path

# Ask for directory path with current directory as default
$dirPath = Read-Host -Prompt "Enter directory path [$currentDir]"
if ([string]::IsNullOrWhiteSpace($dirPath)) {
    $dirPath = $currentDir
}

# Ask which date property to use
Write-Host "`nWhich date property would you like to use?" -ForegroundColor Cyan
Write-Host "1: Creation Time (when the directory was initially created)" -ForegroundColor White
Write-Host "2: Last Write Time (when files in the directory were last added/modified)" -ForegroundColor White
Write-Host "3: Last Access Time (when the directory was last accessed)" -ForegroundColor White
$dateChoice = Read-Host -Prompt "Enter choice (1-3)"

# Set the date property based on choice
$dateProperty = switch ($dateChoice) {
    "1" { "CreationTime"; break }
    "2" { "LastWriteTime"; break }
    "3" { "LastAccessTime"; break }
    default { Write-Host "Invalid choice, using LastWriteTime as default" -ForegroundColor Yellow; "LastWriteTime" }
}

# Ask for number of days
$days = Read-Host -Prompt "`nEnter number of days to look back"

# Validate days input is a number
if (-not [int]::TryParse($days, [ref]$null)) {
    Write-Host "Invalid input for days. Please enter a number." -ForegroundColor Red
    exit
}

# Calculate the cutoff date
$cutoffDate = (Get-Date).AddDays(-[int]$days)

Write-Host "`nSearching for directories with $dateProperty within the last $days days in: $dirPath" -ForegroundColor Cyan
Write-Host "Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

# Get directories based on the selected date property
$scriptBlock = [ScriptBlock]::Create("`$_.$dateProperty -ge `$cutoffDate")
$results = Get-ChildItem -Path $dirPath -Directory | 
    Where-Object -FilterScript $scriptBlock |
    Sort-Object -Property $dateProperty |
    Select-Object @{Name="Directory"; Expression={$_.FullName}}, 
                  @{Name="CreationTime"; Expression={$_.CreationTime}},
                  @{Name="LastWriteTime"; Expression={$_.LastWriteTime}},
                  @{Name="LastAccessTime"; Expression={$_.LastAccessTime}}

# Display results
if ($results.Count -eq 0) {
    Write-Host "No directories found with $dateProperty within the last $days days." -ForegroundColor Yellow
} else {
    Write-Host "`nFound $($results.Count) directories:" -ForegroundColor Green
    
    # Create a simpler view for console display
    $displayResults = $results | Select-Object Directory, @{Name="$dateProperty"; Expression={$_.$dateProperty}}
    $displayResults | Format-Table -AutoSize
    
    # Create output file name based on current date/time and selected property
    $dateStr = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outputFile = Join-Path $currentDir "Dirs_${dateProperty}_last${days}days_${dateStr}.txt"
    
    # Save detailed results to text file
    $results | Format-Table -AutoSize | Out-File -FilePath $outputFile
    
    Write-Host "Detailed results with all date properties saved to: $outputFile" -ForegroundColor Green
}