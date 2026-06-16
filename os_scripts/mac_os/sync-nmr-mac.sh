#!/bin/bash

# --- CONFIGURATION ---
# Replace UNDEFINED with your actual username (e.g., djh35)
USERNAME="UNDEFINED"

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

HOME="/Users/$(whoami)"
LOCALDIR="$HOME/nmr-in/"
IGNORE="$HOME/scripts/ignore"

# --- INTERACTIVE PROMPTS ---
changetime_hours=$1
PASSWORD=$2

if [ -z "$changetime_hours" ]; then
    read -p "Enter the number of hours of data to copy: " changetime_hours
fi

# Ensure hours is actually a number
if ! [[ "$changetime_hours" =~ ^[0-9]+$ ]]; then
    echo "Error: Hours must be a whole number."
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    # -s hides the typing for security
    read -s -p "Enter your password for $USERNAME: " PASSWORD
    echo "" 
fi

echo "Finding and copying $changetime_hours hours of data..."
mkdir -p "$LOCALDIR"

# Mount the drive using the dynamic username and password variables
open "smb://${USERNAME}:${PASSWORD}@nmr-current.ch.private.cam.ac.uk/NMRshares"
sleep 10

# Convert hours to minutes for accurate find targeting
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

    REMOTEDIR="/Volumes/NMRshares/$share_path/"
    
    if cd "$REMOTEDIR" 2>/dev/null; then
        echo "Copying from :- $REMOTEDIR"
        find . -cmin -"$changetime_minutes" -maxdepth 1 \( ! -iname ".*" \) -exec rsync --progress -za --exclude-from="$IGNORE" '{}' "$LOCALDIR" ';'
    else
        echo "Warning: Could not access $REMOTEDIR (Is it mounted?)"
    fi
done

say -v Trinoids "Data transfer complete."