#!/bin/bash

# --- CONFIGURATION ---
# Replace UNDEFINED with your actual username (e.g., djh35)
USERNAME="djh35"
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

HOME="/Users/$(whoami)"
LOCALDIR="$HOME/nmr-in/"

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

# --- EMBEDDED IGNORE LIST ---
IGNORE_FILE="/tmp/nmr_ignore_$$"
cat << 'EOF' > "$IGNORE_FILE"
1i
1r
2rr
2ri
2ir
2ii
3rrr
dsp
dsp.hdr
EOF

# Construct URL correctly using a semicolon if a domain is specified
if [ -n "$DOMAIN" ]; then
    SMB_URI="smb://${DOMAIN};${USERNAME}:${PASSWORD}@nmr-current.ch.private.cam.ac.uk/NMRshares"
else
    SMB_URI="smb://${USERNAME}:${PASSWORD}@nmr-current.ch.private.cam.ac.uk/NMRshares"
fi

open "$SMB_URI"
sleep 10

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
        find . -cmin -"$changetime_minutes" -maxdepth 1 \( ! -iname ".*" \) -exec rsync --progress -za --exclude-from="$IGNORE_FILE" '{}' "$LOCALDIR" ';'
    else
        echo "Warning: Could not access $REMOTEDIR (Is it mounted?)"
    fi
done

# --- CLEANUP ---
rm -f "$IGNORE_FILE"

say -v Trinoids "Data transfer complete."