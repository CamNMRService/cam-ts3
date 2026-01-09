#!/bin/bash
# Linux Computer Inventory Script
# Outputs computer information to a CSV file

# Get computer name
COMPUTER_NAME=$(hostname)

# Get operating system
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
else
    OS_NAME=$(uname -s)
fi

# Get manufacturer
if [ -f /sys/class/dmi/id/sys_vendor ]; then
    MANUFACTURER=$(cat /sys/class/dmi/id/sys_vendor)
else
    MANUFACTURER="Unknown"
fi

# Get CPU type
CPU_TYPE=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)

# Get RAM size in GB
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(echo "scale=2; $RAM_KB / 1024 / 1024" | bc)

# Get network adapter information for 192.168.x.x IP on Ethernet
IP_ADDRESS="N/A"
MAC_ADDRESS="N/A"

# Get all network interfaces (excluding loopback and virtual interfaces)
for interface in $(ls /sys/class/net/ | grep -v "^lo$\|^virbr\|^docker\|^veth\|^br-"); do
    # Check if interface is up
    if [ "$(cat /sys/class/net/$interface/operstate 2>/dev/null)" = "up" ]; then
        # Get IP address for this interface
        IP=$(ip -4 addr show $interface 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep "^192\.168\." | head -1)
        
        if [ ! -z "$IP" ]; then
            # Check if it's a physical Ethernet interface (not wireless)
            if [ -d "/sys/class/net/$interface/device" ] && ! iw dev $interface info &>/dev/null; then
                IP_ADDRESS=$IP
                MAC_ADDRESS=$(cat /sys/class/net/$interface/address)
                break
            fi
        fi
    fi
done

# If no Ethernet found, fall back to any interface with 192.168 IP
if [ "$IP_ADDRESS" = "N/A" ]; then
    for interface in $(ls /sys/class/net/ | grep -v "^lo$\|^virbr\|^docker\|^veth\|^br-"); do
        if [ "$(cat /sys/class/net/$interface/operstate 2>/dev/null)" = "up" ]; then
            IP=$(ip -4 addr show $interface 2>/dev/null | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep "^192\.168\." | head -1)
            
            if [ ! -z "$IP" ]; then
                IP_ADDRESS=$IP
                MAC_ADDRESS=$(cat /sys/class/net/$interface/address)
                break
            fi
        fi
    done
fi

# Create output file
OUTPUT_FILE="ComputerInventory_${COMPUTER_NAME}.csv"

# Write CSV header and data
echo "ComputerName,OperatingSystem,IPAddress,MACAddress,Manufacturer,CPUType,RAMSize_GB" > "$OUTPUT_FILE"
echo "\"$COMPUTER_NAME\",\"$OS_NAME\",\"$IP_ADDRESS\",\"$MAC_ADDRESS\",\"$MANUFACTURER\",\"$CPU_TYPE\",\"$RAM_GB\"" >> "$OUTPUT_FILE"

# Display results
echo -e "\033[0;32mInventory data exported to: $OUTPUT_FILE\033[0m"
echo ""
echo -e "\033[0;36mComputer Details:\033[0m"
echo "ComputerName: $COMPUTER_NAME"
echo "OperatingSystem: $OS_NAME"
echo "IPAddress: $IP_ADDRESS"
echo "MACAddress: $MAC_ADDRESS"
echo "Manufacturer: $MANUFACTURER"
echo "CPUType: $CPU_TYPE"
echo "RAMSize_GB: $RAM_GB"