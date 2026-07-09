# Windows powershell version Sync-NMRData.ps1
# --- CONFIGURATION ---
# Replace UNDEFINED with your actual username (e.g., djh35)
$Username = "UNDEFINED"

# --- USERNAME CHECK ---
if ($Username -eq "UNDEFINED") {
    Write-Warning "Error: Username is not set."
    Write-Host "Please open this script in a text editor (like Notepad or PowerShell ISE) and change `$Username = `"UNDEFINED`" to your actual username."
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
    # Prompt securely so the password is hidden while typing
    $SecurePassword = Read-Host "Enter your password for $Username" -AsSecureString
    # Convert secure string to plain text for the 'net use' command
    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecurePassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
}

$LocalDir = "$HOME\nmr-in"
$IgnoreFile = "$HOME\scripts\ignore"

if (-not (Test-Path $LocalDir)) { New-Item -ItemType Directory -Path $LocalDir | Out-Null }

Write-Host "Finding and copying $ChangetimeHours hours of data..."

# Authenticate with the network share directly using the variable
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
            Copy-Item -Path $_.FullName -Destination $LocalDir -Recurse -Force
        }
    } else {
        Write-Warning "Could not access $RemoteDir"
    }
}

$Voice = New-Object -ComObject SAPI.SpVoice
$Voice.Speak("Data transfer complete")