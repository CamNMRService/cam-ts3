#!/bin/bash

# Usage: ./combine_csv.sh <directory> <output_file>
# Example: ./combine_csv.sh /path/to/csvs output.csv

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <directory> <output_file>"
    exit 1
fi

DIR="$1"
OUTPUT="$2"

# Check if directory exists
if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist"
    exit 1
fi

# Get all CSV files sorted alphabetically
CSV_FILES=($(ls -1 "$DIR"/*.csv 2>/dev/null | sort))

# Check if any CSV files were found
if [ ${#CSV_FILES[@]} -eq 0 ]; then
    echo "Error: No CSV files found in '$DIR'"
    exit 1
fi

# Clear output file if it exists
> "$OUTPUT"

# Process first CSV file - get first two lines
FIRST_FILE="${CSV_FILES[0]}"
head -n 2 "$FIRST_FILE" > "$OUTPUT"

echo "Added first 2 lines from: $(basename "$FIRST_FILE")"

# Process remaining CSV files - get only second line
for (( i=1; i<${#CSV_FILES[@]}; i++ )); do
    FILE="${CSV_FILES[$i]}"
    sed -n '2p' "$FILE" >> "$OUTPUT"
    echo "Added line 2 from: $(basename "$FILE")"
done

echo ""
echo "Combined CSV created: $OUTPUT"
echo "Total files processed: ${#CSV_FILES[@]}"
