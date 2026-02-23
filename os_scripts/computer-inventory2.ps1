# Windows Computer Inventory Script
# Outputs computer information to a CSV file

# Get computer system information
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
$computerName = $env:COMPUTERNAME
$manufacturer = $computerSystem.Manufacturer

# Get operating system information
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$osName = $os.Caption

# Get processor information
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuType = $cpu.Name

# Get RAM size in GB
$ramBytes = $computerSystem.TotalPhysicalMemory
$ramGB = [math]::Round($ramBytes / 1GB, 2)

# Get network adapter information for 192.168.x.x IP on Ethernet
$ipAddress = $null
$macAddress = $null

$adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { 
    $_.IPEnabled -eq $true 
}

foreach ($adapter in $adapters) {
    # Check if this adapter has an IP address starting with 192.168
    $targetIP = $adapter.IPAddress | Where-Object { $_ -match '^192\.168\.' } | Select-Object -First 1
    
    if ($targetIP) {
        # Get the adapter details
        $adapterDetails = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { 
            $_.Index -eq $adapter.Index 
        }
        
        # Prefer physical Ethernet adapters, but accept any adapter with 192.168 IP
        # Exclude only virtual adapters and Bluetooth
        if ($adapterDetails.Name -notmatch 'Virtual|Bluetooth|VirtualBox|VMware') {
            $ipAddress = $targetIP
            $macAddress = $adapter.MACAddress
            
            # If it's explicitly an Ethernet adapter, use it and stop searching
            if ($adapterDetails.Name -match 'Ethernet') {
                break
            }
        }
    }
}

# Create custom object with all information
$inventoryData = [PSCustomObject]@{
    ComputerName  = $computerName
    OperatingSystem = $osName
    IPAddress     = if ($ipAddress) { $ipAddress } else { "N/A" }
    MACAddress    = if ($macAddress) { $macAddress } else { "N/A" }
    Manufacturer  = $manufacturer
    CPUType       = $cpuType
    RAMSize_GB    = $ramGB
}

# Output to CSV file
$outputFile = "ComputerInventory_$computerName.csv"
$inventoryData | Export-Csv -Path $outputFile -NoTypeInformation -Force

Write-Host "Inventory data exported to: $outputFile" -ForegroundColor Green
Write-Host ""
Write-Host "Computer Details:" -ForegroundColor Cyan
$inventoryData | Format-List