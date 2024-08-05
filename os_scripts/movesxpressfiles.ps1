#to enable exectuing powershell scripts:
# Open powershell as administrator, and run:
# set-executionpolicy remotesigned

# set this as appropriate
$FolderPath = "C:\Users\chemist\SXpresslog"

# Get all files in the specified folder
$FilesToMove = Get-ChildItem -Path $FolderPath | Where-Object { $_.Name -like "*@ewpres*" }

# Create subfolders based on modification date
foreach ($file in $FilesToMove) {
    $date = Get-Date ($file.LastWriteTime)
    $year = $date.Year
    $month = $date.Month
    $day = $date.Day
    $MonthPath = "$FolderPath\$year\$month\$day"

    if (!(Test-Path -Path $MonthPath)) {
        New-Item -ItemType directory -Path $MonthPath | Out-Null
    }

    # Rename the file with modification date and time (including seconds) and .png extension
    $newFileName = "{0:yyyyMMdd-HHmmss}.png" -f $date
    $newFilePath = Join-Path -Path $MonthPath -ChildPath $newFileName
    Move-Item -Path $file.FullName -Destination $newFilePath -Force
}

Write-Host "All files have been sorted into subfolders based on modification date and renamed."