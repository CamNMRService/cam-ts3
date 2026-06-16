#!/bin/bash

# --- CONFIGURATION ---
# Replace UNDEFINED with your actual username (e.g., djh35)
USERNAME="UNDEFINED"
# Optional: If your network requires a domain (e.g., ad), enter it below. Leave blank if not.
DOMAIN="ad"

# --- USERNAME CHECK ---
if [ "$USERNAME" = "UNDEFINED" ]; then
    echo "Error: USERNAME is not set."
    echo "Please open this script in a text editor and change USERNAME=\"UNDEFINED\" to your actual username."
    exit 1
fi

# --- HELP & ARGUMENT CATCH ---
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: ./sync-nmr.sh [hours] [password]"
    echo "If you run the script without arguments, it will prompt you for them."
    exit 0
fi

HOME="/home/$(whoami)"
LOCALDIR="$HOME/nmr-in/"
IGNORE="$HOME/scripts/ignore"

# --- INTERACTIVE PROMPTS ---
changetime_hours=$1
PASSWORD=$2

if [ -z "$changetime_hours" ]; then
    read -p "Enter the number of hours of data to copy: " changetime_hours
fi

if ! [[ "$changetime_hours" =~ ^[0-9]+$ ]]; then
    echo "Error: Hours must be a whole number."
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    if [ -n "$DOMAIN" ]; then
        read -s -p "Enter your password for ${DOMAIN}\\${USERNAME}: " PASSWORD
    else
        read -s -p "Enter your password for $USERNAME: " PASSWORD
    fi
    echo "" 
fi

echo "Finding and copying $changetime_hours hours of data..."
mkdir -p "$LOCALDIR"

# --- MOUNT PROCESS ---
if command -v gio &> /dev/null; then
    echo "Mounting network share..."
    
    # Send credentials sequentially into the mount prompt sequence.
    printf "%s\n%s\n%s\n" "${USERNAME}" "${DOMAIN:-WORKGROUP}" "${PASSWORD}" | gio mount "smb://nmr-current.ch.private.cam.ac.uk/NMRshares" >/dev/null 2>&1
    
    # Give GVFS a brief moment to initialize the mount path mapping
    sleep 2
    
    # Dynamically locate the mount directory to support varying GVFS naming schemas
    MOUNT=$(ls -d /run/user/$(id -u)/gvfs/*nmr-current.ch.private.cam.ac.uk* 2>/dev/null | head -n 1)
else
    # Fallback for legacy environments
    MOUNT="/mnt/NMRshares"
fi

# Verification check
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
    echo "Error: Could not mount or locate the network directory."
    echo "Please verify your network connection, username, domain, and password."
    exit 1
fi

changetime_minutes=$((changetime_hours * 60))

for share_path in \
    "aberlour/nmrservice/nmr" \
    "glenlivet2/service/nmr" \
    "auchentoshan/service/nmr" \
    "glengrant/service/nmr" \
    "cragganmore/service/nmr" \
    "arran/service/nmr" \
    "tobermory/service/nmr" \
    "glenfairn/service/nmr"; do

    REMOTEDIR="$MOUNT/$share_path/"
    
    if cd "$REMOTEDIR" 2>/dev/null; then
        echo "Copying from :- $REMOTEDIR"
        # FIXED: -maxdepth 1 is now placed before -cmin
        find . -maxdepth 1 -cmin -"$changetime_minutes" \( ! -iname ".*" \) -exec rsync --progress -za --exclude-from="$IGNORE" '{}' "$LOCALDIR" ';'
    else
        echo "Warning: Could not access $REMOTEDIR (Skipping)"
    fi
done

if command -v spd-say &> /dev/null; then
    spd-say "Data transfer complete."
fi
echo "Done!"