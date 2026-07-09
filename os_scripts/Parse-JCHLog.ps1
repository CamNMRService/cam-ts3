param(
    [Parameter(Mandatory=$true)]
    [string]$StartMonth,

    [Parameter(Mandatory=$true)]
    [int]$StartYear
)

$MonthMap = @{
    Jan = 1; Feb = 2; Mar = 3; Apr = 4;
    May = 5; Jun = 6; Jul = 7; Aug = 8;
    Sep = 9; Oct = 10; Nov = 11; Dec = 12
}

if (-not $MonthMap.ContainsKey($StartMonth)) {
    Write-Host "Invalid month abbreviation"
    exit
}

$StartDate = Get-Date -Day 1 -Month $MonthMap[$StartMonth] -Year $StartYear

$ExptCounts = @{}
$Entries = @()

$lines = Get-Content "jchlog.txt"

$dateRegex = "^\w+\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{2}:\d{2}:\d{2})\s+(\d{4})$"

$currentDate = $null
$currentSpec = $null

foreach ($line in $lines) {

    $trim = $line.Trim()

    # Detect date line
    if ($trim -match $dateRegex) {
        $mon  = $matches[1]
        $day  = $matches[2]
        $time = $matches[3]
        $year = $matches[4]

        $dateString = "$day $mon $year $time"
        $currentDate = [datetime]::ParseExact($dateString, "d MMM yyyy HH:mm:ss", $null)

        $currentSpec = $null
        continue
    }

    # Detect Specno line
    if ($trim -like "Specno:*") {
        $currentSpec = $trim
        continue
    }

    # Detect completion line
    if ($trim -like "Sample completed*") {

        if ($currentDate -and $currentSpec -and $currentDate -ge $StartDate) {

            # Extract Expt between Expt= and next comma
            $expt = "UNKNOWN"
            if ($currentSpec -match "Expt=\s*([^,]+)") {
                $expt = $matches[1].Trim()
            }

            # Count
            if ($ExptCounts.ContainsKey($expt)) {
                $ExptCounts[$expt]++
            } else {
                $ExptCounts[$expt] = 1
            }

            # Store entry
            $Entries += [PSCustomObject]@{
                Expt     = $expt
                Date     = $currentDate
                SpecLine = $currentSpec
            }
        }

        $currentDate = $null
        $currentSpec = $null
    }
}

# Sort entries
$SortedEntries = $Entries | Sort-Object Expt, Date

# --- EXPORT SUMMARY TO CSV ---
$SummaryRows = foreach ($key in $ExptCounts.Keys) {
    [PSCustomObject]@{
        Expt  = $key
        Count = $ExptCounts[$key]
    }
}

$SummaryRows | Sort-Object Expt | Export-Csv -Path "ExptSummary.csv" -NoTypeInformation
Write-Host "`nSummary exported to ExptSummary.csv"

# --- WRITE GROUPED OUTPUT TO FILE ---
$outFile = "groupedexperiments.txt"
"" | Out-File $outFile   # clear file

$Grouped = $SortedEntries | Group-Object Expt

foreach ($group in $Grouped) {
    "===== $($group.Name) =====" | Out-File $outFile -Append
    foreach ($entry in $group.Group) {
        $entry.SpecLine | Out-File $outFile -Append
    }
    "" | Out-File $outFile -Append
}

Write-Host "`nGrouped Specno lines written to groupedexperiments.txt"

