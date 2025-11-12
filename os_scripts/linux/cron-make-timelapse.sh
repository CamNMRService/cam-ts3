
#!/bin/bash
SCRIPT_DIR="/root/scripts"
INPUT_DIR="/mnt/webcam_captures/"
OUTPUT_DIR="/mnt/bag_movies/mp4/"

"$SCRIPT_DIR/make-timelapse-mpgs.sh" "$INPUT_DIR" "$OUTPUT_DIR"
