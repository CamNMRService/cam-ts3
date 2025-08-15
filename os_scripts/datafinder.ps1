#Script to find data by searching for a string in just files of a given name (default acqus)
# To find data for a given nucleus use NUC1= <11B> or whatever
# Note that searching for NUC1= <1H> will find proton, cosy , HSQC, HMBC...
# Can optionally add second string - just hit return if not needed.

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

# Search logic
Get-ChildItem -Recurse -Filter $filename -File | Where-Object {
    $path = $_.FullName
    $match1 = Select-String -Path $path -Pattern $searchString1 -Quiet
    if (-not $match1) { return $false }

    if (-not [string]::IsNullOrWhiteSpace($searchString2)) {
        $match2 = Select-String -Path $path -Pattern $searchString2 -Quiet
        return $match2
    }

    return $true
} | Select-Object -ExpandProperty FullName



