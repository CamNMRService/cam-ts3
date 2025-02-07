#########
#run with powershell.exe -noprofile -executionpolicy bypass -file .\manage_janus.ps1
# Parameters for the script
param(
    [string]$TargetIP = "192.168.200.9",  # Default to arran change as needed
    [int]$WaitTimeSeconds = 30,      # Wait time between connection attempts
    [string]$JanusPath = "C:\nmrKiosk\nmrkiosk.exe" # Path to Janus executable
)

function Get-TimeStamp {
    return "[{0:MM/dd/yyyy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Test-NetworkConnection {
    param([string]$IP)
    $result = Test-Connection -ComputerName $IP -Count 1 -ErrorAction SilentlyContinue
    if ($result) {
        return @{
            Success = $true
            ResponseTime = $result.ResponseTime
        }
    }
    return @{
        Success = $false
        ResponseTime = 0
    }
}

function Is-ProcessRunning {
    param([string]$ProcessName)
    return Get-Process $ProcessName -ErrorAction SilentlyContinue
}

function Stop-JanusProcess {
    $janusProcess = Is-ProcessRunning -ProcessName "nmrkiosk"
    if ($janusProcess) {
        Write-Host "$(Get-TimeStamp) Stopping Janus process due to network disconnection..."
        try {
            Stop-Process -Name "nmrkiosk" -Force
            Write-Host "$(Get-TimeStamp) Successfully stopped Janus process"
        }
        catch {
            Write-Host "$(Get-TimeStamp) ERROR: Failed to stop Janus process: $_"
        }
    }
}

Write-Host "$(Get-TimeStamp) Script started. Monitoring network connection to $TargetIP"
Write-Host "$(Get-TimeStamp) Checking for Janus executable at: $JanusPath"
Write-Host "$(Get-TimeStamp) Network check interval set to: $WaitTimeSeconds seconds"
Write-Host "-----------------------------------------------------------"

# Main loop
$attemptCount = 1
while ($true) {
    Write-Host "$(Get-TimeStamp) Connection attempt #$attemptCount"
    
    $connectionResult = Test-NetworkConnection -IP $TargetIP
    
    if ($connectionResult.Success) {
        Write-Host "$(Get-TimeStamp) Network connection established (Response time: $($connectionResult.ResponseTime)ms)"
        
        # Check if Janus is already running
        $janusProcess = Is-ProcessRunning -ProcessName "nmrkiosk"
        
        if (-not $janusProcess) {
            Write-Host "$(Get-TimeStamp) Janus is not running - attempting to start..."
            try {
                Start-Process $JanusPath
                Write-Host "$(Get-TimeStamp) Successfully launched Janus application"
                Write-Host "$(Get-TimeStamp) Process ID: $((Get-Process "nmrkiosk").Id)"
            }
            catch {
                Write-Host "$(Get-TimeStamp) ERROR: Failed to start Janus: $_"
                Write-Host "$(Get-TimeStamp) Please verify the path: $JanusPath"
            }
        }
        else {
            Write-Host "$(Get-TimeStamp) Janus is already running"
            Write-Host "$(Get-TimeStamp) Process ID: $($janusProcess.Id)"
            Write-Host "$(Get-TimeStamp) Running since: $($janusProcess.StartTime)"
        }
    }
    else {
        Write-Host "$(Get-TimeStamp) Network connection failed"
        # New functionality: Stop Janus process when network is down
        Stop-JanusProcess
        Write-Host "$(Get-TimeStamp) Waiting $WaitTimeSeconds seconds before retry..."
        Write-Host "$(Get-TimeStamp) Next attempt will be at: $((Get-Date).AddSeconds($WaitTimeSeconds))"
    }
    
    Write-Host "-----------------------------------------------------------"
    Start-Sleep -Seconds $WaitTimeSeconds
    $attemptCount++
}
