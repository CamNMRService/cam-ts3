cd "C:\Users\nmrservice\Pictures\Camera Roll"
# Get yesterday's date
$yesterday = (Get-Date).AddDays(-3)

# Format yesterday's date as Day-Month-Year (e.g., 17-Mar-2024)
$folderName = $yesterday.ToString("MMM-dd-yyyy")

# Create the folder
New-Item -ItemType Directory -Path ".\$folderName\pictures" | Out-Null

# Define the pattern for filename matching
$pattern = $yesterday.ToString("yyyyMMdd")

# Move JPG files matching the pattern to the created folder
Get-ChildItem -Filter "*.jpg" | Where-Object { $_.BaseName -match $pattern } | Move-Item -Destination ".\$folderName\pictures"