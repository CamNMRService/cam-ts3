# --- CONFIGURATION ---
# Replace UNDEFINED with your actual username (e.g., djh35)
$Username = "UNDEFINED"

# --- USERNAME CHECK ---
if ($Username -eq "UNDEFINED") {
    Write-Warning "Error: Username is not set."
    Write-Host "Please open this script in a text editor and change `$Username = `"UNDEFINED`" to your actual username."
    exit
}

$ChangetimeHours = $args[0]
$PlainPassword = $args[1]

# --- HELP CATCH ---
if ($ChangetimeHours -eq "help" -or $ChangetimeHours -eq "-h" -or $ChangetimeHours -eq "--help") {
    Write-Host "Usage: .\Sync-NMRData.ps1 [hours] [password]"
    Write-Host "If omitted, the script will prompt you for the required values."
    exit
}

# --- INTERACTIVE PROMPTS ---
if (-not $ChangetimeHours) {
    $ChangetimeHours = Read-Host "Enter the number of hours of data to copy"
}

if (-not ($ChangetimeHours -match '^\d+$')) {
    Write-Error "Error: Hours must be a whole number!"
    exit
}

if (-not $PlainPassword) {
    $SecurePassword = Read-Host "Enter your password for $Username" -AsSecureString
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecurePassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
}

$LocalDir = "$HOME\nmr-in"
$IgnoreFile = "$HOME\scripts\ignore"

if (-not (Test-Path $LocalDir)) { New-Item -ItemType Directory -Path $LocalDir | Out-Null }

Write-Host "Finding and copying $ChangetimeHours hours of data..."

# Authenticate with the network share
$NetworkPath = "\\nmr-current.ch.private.cam.ac.uk\NMRshares"
net use $NetworkPath $PlainPassword /user:$Username *>$null

$CutoffDate = (Get-Date).AddHours(-$ChangetimeHours)

$IgnoreList = @()
if (Test-Path $IgnoreFile) { $IgnoreList = Get-Content $IgnoreFile }

$Shares = @(
    "aberlour\nmrservice\nmr",
    "glenlivet2\service\nmr",
    "auchentoshan\service\nmr",
    "glengrant\service\nmr",
    "cragganmore\service\nmr",
    "arran\service\nmr",
    "tobermory\service\nmr",
    "glenfairn\service\nmr"
)

foreach ($Share in $Shares) {
    $RemoteDir = Join-Path $NetworkPath $Share
    
    if (Test-Path $RemoteDir) {
        Write-Host "Copying from :- $RemoteDir"
        
        Get-ChildItem -Path $RemoteDir | Where-Object {
            $_.LastWriteTime -gt $CutoffDate -and 
            $_.Name -notlike ".*" -and
            $IgnoreList -notcontains $_.Name
        } | ForEach-Object {
            $Item = $_
            
            # 1. Print the file being copied, leaving the cursor at the end of the line
            Write-Host "   -> Copying: $($Item.Name)... " -NoNewline
            
            # 2. Start the timer
            $Sw = [System.Diagnostics.Stopwatch]::StartNew()
            
            # 3. Perform the actual copy
            if ($Item.PSIsContainer) {
                Copy-Item -Path $Item.FullName -Destination $LocalDir -Recurse -Force
                
                # Measure folder size locally to save network bandwidth overhead
                $LocalPath = Join-Path $LocalDir $Item.Name
                $SizeInBytes = (Get-ChildItem -Path $LocalPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $SizeInBytes) { $SizeInBytes = 0 }
            } else {
                $SizeInBytes = $Item.Length
                Copy-Item -Path $Item.FullName -Destination $LocalDir -Force
            }
            
            # 4. Stop the timer
            $Sw.Stop()
            $TotalSeconds = $Sw.Elapsed.TotalSeconds
            
            # 5. Calculate rates and append the completion details to the console line
            if ($TotalSeconds -gt 0.1 -and $SizeInBytes -gt 1024) {
                $SizeInMB = $SizeInBytes / 1MB
                $SpeedMBs = $SizeInMB / $TotalSeconds
                Write-Host "Done! ($("{0:N2}" -f $SizeInMB) MB @ $("{0:N2}" -f $SpeedMBs) MB/s)"
            } else {
                # For very small items that copy under 0.1s, report in KB to avoid skewed math
                $SizeInKB = $SizeInBytes / 1KB
                Write-Host "Done! ($("{0:N2}" -f $SizeInKB) KB copied instantly)"
            }
        }
    } else {
        Write-Warning "Could not access $RemoteDir"
    }
}

$Voice = New-Object -ComObject SAPI.SpVoice
$Voice.Speak("Data transfer complete")