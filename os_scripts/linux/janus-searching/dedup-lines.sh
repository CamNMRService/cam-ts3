#!/bin/bash

# Prompt the user for the file path
read -r -p "Enter the path to your text file: " filepath

# Strip leading/trailing quotes (useful if file was dragged into the terminal)
filepath="${filepath%\"}"
filepath="${filepath#\"}"
filepath="${filepath%\'}"
filepath="${filepath#\'}"

# Expand tilde ~ if present
filepath="${filepath/#\~/$HOME}"

# Check if the file exists
if [ ! -f "$filepath" ]; then
    echo "Error: File '$filepath' does not exist."
    exit 1
fi

# Define output file path (appends _sorted before extension)
if [[ "$filepath" == *.* ]]; then
    output_file="${filepath%.*}_sorted.${filepath##*.}"
else
    output_file="${filepath}_sorted"
fi

# Sort and deduplicate (works on both BSD/macOS and GNU/Linux)
sort -u "$filepath" -o "$output_file"

echo "Done! Cleaned and sorted file saved to: $output_file"

