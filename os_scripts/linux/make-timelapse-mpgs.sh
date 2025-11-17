#!/bin/bash

# Image to Video Processing Script
# Processes JPG images into MPG videos and organizes them by date
# Usage: ./process_images.sh [source_directory] [output_directory]

# Removed set -e to prevent early exits

# Configuration
#SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="/root/scripts"
LOG_FILE="${SCRIPT_DIR}/image_processor.log"
TEMP_DIR="${SCRIPT_DIR}/temp_processing"
TODAY=$(date +%Y%m%d)

# Video settings
VIDEO_FPS=60
VIDEO_QUALITY=2  # CRF value for x264 (lower = better quality)

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <source_directory> <output_directory>"
    echo "  source_directory: Directory containing JPG files"
    echo "  output_directory: Directory where organized files will be stored"
    exit 1
}

# Function to validate directory
validate_directory() {
    local dir="$1"
    local desc="$2"
    
    if [[ ! -d "$dir" ]]; then
        log_message "ERROR" "$desc directory does not exist: $dir"
        exit 1
    fi
    
    if [[ ! -r "$dir" ]]; then
        log_message "ERROR" "$desc directory is not readable: $dir"
        exit 1
    fi
    
    if [[ "$desc" == "Output" ]] && [[ ! -w "$dir" ]]; then
        log_message "ERROR" "$desc directory is not writable: $dir"
        exit 1
    fi
}

# Function to extract date from filename
extract_date_from_filename() {
#capture_20251110_142136.jpg
    local filename="$1"
    # Extract YYYYMMDD from WIN_YYYYMMDD_Hour_Minute_second_Pro.jpg
    if [[ "$filename" =~ capture_([0-9]{8})_[0-9]{2}[0-9]{2}[0-9]{2}\.jpg$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to format date for directory structure
format_date_for_directory() {
    local date_str="$1"
    # Convert YYYYMMDD to YYYY_MM_DD
    echo "${date_str:0:4}_${date_str:4:2}_${date_str:6:2}"
}

# Function to get image resolution
get_image_resolution() {
    local image_file="$1"
    # Use identify from ImageMagick to get resolution
    if command -v identify >/dev/null 2>&1; then
        identify -format "%wx%h" "$image_file" 2>/dev/null
    else
        # Fallback to ffprobe if ImageMagick not available
        ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$image_file" 2>/dev/null
    fi
}

# Function to create video from images
create_video_from_images() {
    local date_str="$1"
    local formatted_date="$2"
    local output_dir="$3"
    local temp_list_file="$4"
    local image_count="$5"
    
    local mpg_dir="${output_dir}/${formatted_date}/mpg"
    local mpg_file="${mpg_dir}/${formatted_date}.mpg"
    local mpg_file_tmp="${TEMP_DIR}/${formatted_date}.mpg"
    # Create MPG directory
    mkdir -p "$mpg_dir"
    
    log_message "INFO" "Creating video for date $date_str with $image_count images"
    
    # Get resolution from first image
    local first_image
    first_image=$(head -n1 "$temp_list_file" | cut -d'|' -f1)
    local resolution
    resolution=$(get_image_resolution "$first_image")
    
    if [[ -z "$resolution" ]]; then
        log_message "WARN" "Could not determine resolution, using default 1920x1080"
        resolution="1920x1080"
    fi
    
    log_message "INFO" "Using resolution: $resolution"
    
    # Create temporary directory for symlinks
    local temp_img_dir="${TEMP_DIR}/${formatted_date}_images"
    mkdir -p "$temp_img_dir"
    
    # Create sequential symlinks for ffmpeg
    local counter=1
    while IFS='|' read -r img_path img_name; do
        local symlink_name=$(printf "%08d.jpg" $counter)
        ln -sf "$img_path" "${temp_img_dir}/${symlink_name}"
        ((counter++))
    done < "$temp_list_file"
    
    # Create video using ffmpeg with better settings for large image sequences
    local ffmpeg_cmd=(
        ffmpeg
        -y
        -framerate "$VIDEO_FPS"
        -i "${temp_img_dir}/%08d.jpg"
        -c:v libx264
        -crf "$VIDEO_QUALITY"
        -pix_fmt yuv420p
        -s "$resolution"
        -r "$VIDEO_FPS"
        -bufsize 64M
        -maxrate 50M
        -f mpeg
        "$mpg_file_tmp"
    )
    
    log_message "INFO" "Running ffmpeg command: ${ffmpeg_cmd[*]}"
    
    # Run ffmpeg and capture both stdout and stderr
    if "${ffmpeg_cmd[@]}" </dev/null 2>&1 | tee -a "$LOG_FILE" | grep -q "Error\|error\|Error opening\|No such file" && [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_message "ERROR" "Failed to create video for date $date_str"
        rm -rf "$temp_img_dir"
        return 1
    elif [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_message "INFO" "Successfully created video: $mpg_file_tmp"
        
        # Verify video file exists and has size > 0
        if [[ -f "$mpg_file" ]] && [[ -s "$mpg_file" ]]; then
            log_message "INFO" "Video verification passed for $mpg_file_tmp"
            #made a tmp mpg as writing to a shared directory syning on onedrive lead to unexpected behaviour - pauses
            cp $mpg_file_tmp $mpg_file
            # Clean up temporary symlinks
            rm -rf "$temp_img_dir"
            
            return 0
        else
            log_message "ERROR" "Video file is empty or missing: $mpg_file_tmp"
            rm -rf "$temp_img_dir"
            return 1
        fi
    else
        log_message "ERROR" "Failed to create video for date $date_str"
        rm -rf "$temp_img_dir"
        return 1
    fi
}

# Function to move processed images
move_processed_images() {
    local formatted_date="$1"
    local output_dir="$2"
    local temp_list_file="$3"
    
    local jpg_dir="${output_dir}/${formatted_date}/jpg"
    mkdir -p "$jpg_dir"
    
    log_message "INFO" "Moving processed images to $jpg_dir"
    
    local moved_count=0
    local failed_count=0
    
    while IFS='|' read -r img_path img_name; do
        local dest_path="${jpg_dir}/${img_name}"
        
        if mv "$img_path" "$dest_path" 2>>"$LOG_FILE"; then
            ((moved_count++))
        else
            log_message "ERROR" "Failed to move image: $img_path"
            ((failed_count++))
        fi
    done < "$temp_list_file"
    
    log_message "INFO" "Moved $moved_count images, $failed_count failures"
    
    # Return 0 for success (even if some moves failed, we don't want to stop processing)
    # Log the failures but continue
    return 0
}

# Function to process images for a specific date
process_date_group() {
    local date_str="$1"
    local source_dir="$2"
    local output_dir="$3"
    
    log_message "INFO" "ENTERED process_date_group for date: $date_str"
    
    local formatted_date
    formatted_date=$(format_date_for_directory "$date_str")
    
    log_message "INFO" "Processing images for date: $date_str ($formatted_date)"
    
    # Create temporary file list for this date
    local temp_list_file="${TEMP_DIR}/images_${date_str}.list"
    
    # Find all images for this date (only in root directory)
    local image_count=0
    > "$temp_list_file"  # Clear the file first
    
    log_message "INFO" "Scanning for images with date: $date_str"
    
    while IFS= read -r -d '' img_file; do
        local img_name
        img_name=$(basename "$img_file")
        local file_date
        file_date=$(extract_date_from_filename "$img_name")
        
        if [[ "$file_date" == "$date_str" ]]; then
            echo "${img_file}|${img_name}" >> "$temp_list_file"
            image_count=$((image_count + 1))
        fi
    done < <(find "$source_dir" -maxdepth 1 -name "capture_*.jpg" -type f -print0)
    
    log_message "INFO" "Finished scanning, found $image_count images for date $date_str"
    
    if [[ $image_count -eq 0 ]]; then
        log_message "WARN" "No images found for date $date_str"
        rm -f "$temp_list_file"
        log_message "INFO" "EXITING process_date_group for date: $date_str (no images)"
        return 0
    fi
    
    log_message "INFO" "Found $image_count images for date $date_str"
    
    # Sort the list by filename to ensure chronological order
    sort -t'|' -k2 "$temp_list_file" -o "$temp_list_file"
    
    log_message "INFO" "About to create video for date: $date_str"
    
    # Create video from images
    local video_result=0
    create_video_from_images "$date_str" "$formatted_date" "$output_dir" "$temp_list_file" "$image_count" || video_result=$?
    
    if [[ $video_result -eq 0 ]]; then
        log_message "INFO" "Video creation successful for date: $date_str"
        # Move images only if video creation succeeded
        move_processed_images "$formatted_date" "$output_dir" "$temp_list_file"
        log_message "INFO" "Successfully processed all images for date $date_str"
        # Clean up temporary list file
        rm -f "$temp_list_file"
        log_message "INFO" "EXITING process_date_group for date: $date_str (success)"
        return 0
    else
        log_message "ERROR" "Video creation failed for date $date_str (exit code: $video_result), keeping original images"
        # Clean up temporary list file
        rm -f "$temp_list_file"
        log_message "INFO" "EXITING process_date_group for date: $date_str (video failed)"
        return 1
    fi
}

# Main function
main() {
    log_message "INFO" "Starting image processing script"
    
    # Check arguments
    if [[ $# -ne 2 ]]; then
        show_usage
    fi
    
    local source_dir="$1"
    local output_dir="$2"
    
    # Validate directories
    validate_directory "$source_dir" "Source"
    validate_directory "$output_dir" "Output"
    
    # Check required commands
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_message "ERROR" "ffmpeg is not installed or not in PATH"
        exit 1
    fi
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Cleanup function - only clean up at the very end
    cleanup() {
        log_message "INFO" "Cleaning up temporary files"
        rm -rf "$TEMP_DIR"
    }
    
    log_message "INFO" "Source directory: $source_dir"
    log_message "INFO" "Output directory: $output_dir"
    log_message "INFO" "Ignoring files from today: $TODAY"
    
    # Get unique dates from filenames (excluding today)
    local dates_to_process=()
    
    log_message "INFO" "Scanning for image files..."
    
    while IFS= read -r -d '' img_file; do
        local img_name
        img_name=$(basename "$img_file")
        local file_date
        file_date=$(extract_date_from_filename "$img_name")
        
        if [[ -n "$file_date" ]] && [[ "$file_date" != "$TODAY" ]]; then
            # Add to array if not already present
            if [[ ! " ${dates_to_process[*]} " =~ " ${file_date} " ]]; then
                dates_to_process+=("$file_date")
            fi
        fi
    done < <(find "$source_dir" -maxdepth 1 -name "capture_*.jpg" -type f -print0)
    
    if [[ ${#dates_to_process[@]} -eq 0 ]]; then
        log_message "INFO" "No images found to process"
        exit 0
    fi
    
    # Sort dates
    IFS=$'\n' dates_to_process=($(sort <<<"${dates_to_process[*]}"))
    unset IFS
    
    log_message "INFO" "Found ${#dates_to_process[@]} date(s) to process: ${dates_to_process[*]}"
    
    # Process each date
    local processed_count=0
    local failed_count=0
    
    log_message "INFO" "About to start processing loop for ${#dates_to_process[@]} dates"
    
    for date_str in "${dates_to_process[@]}"; do
        log_message "INFO" "=== Starting processing for date: $date_str ==="
        log_message "INFO" "Current progress: processed=$processed_count, failed=$failed_count"
        
        # Process the date group and capture return code explicitly
        local result=0
        process_date_group "$date_str" "$source_dir" "$output_dir" || result=$?
        
        if [[ $result -eq 0 ]]; then
            processed_count=$((processed_count + 1))
            log_message "INFO" "=== Completed processing for date: $date_str ==="
        else
            failed_count=$((failed_count + 1))
            log_message "ERROR" "=== Failed processing for date: $date_str (exit code: $result) ==="
        fi
        
        log_message "INFO" "Progress after $date_str: $((processed_count + failed_count))/${#dates_to_process[@]} dates processed"
        log_message "INFO" "About to continue to next date in loop"
        
        # Add a small delay to prevent resource exhaustion
        sleep 2
    done
    
    log_message "INFO" "=== COMPLETED PROCESSING LOOP ==="
    
    log_message "INFO" "Processing complete. Processed: $processed_count, Failed: $failed_count"
    
    # Clean up at the end
    cleanup
    
    if [[ $failed_count -gt 0 ]]; then
        exit 1
    fi
}

# Run main function
main "$@"

